require "google/apis/tasks_v1"
require 'googleauth'
require 'googleauth/stores/file_token_store'

module Deed
  class Google_api
    attr_reader :credentials
    # Authorize google client
    def initialize
      deed_config = Deed::Config.new
      config_file = deed_config.config_file
      oob_uri = 'urn:ietf:wg:oauth:2.0:oob'
      scope = 'https://www.googleapis.com/auth/tasks'
      client_id = Google::Auth::ClientId.from_file("#{config_file[:path]}/client_id.json")
      token_store = Google::Auth::Stores::FileTokenStore.new(
        :file => "#{config_file[:path]}/tokens.yaml")
      authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
      user_id = "zomundo@gmail.com"
      @credentials = authorizer.get_credentials(user_id)
      if credentials.nil?
        url = authorizer.get_authorization_url(base_url: oob_uri )
        STDOUT.puts "Open #{url} in your browser and enter the resulting code:"
        code = STDIN.gets
        @credentials = authorizer.get_and_store_credentials_from_code(
          user_id: user_id, code: code, base_url: oob_uri)
      end
    end
    # Get all task lists
    # @return task lists
    def task_lists
      tasks_client = Google::Apis::TasksV1::TasksService.new
      tasks_client.authorization = @credentials
      return tasks_client.list_tasklists
    end
    # Get a task lists
    # @param task_list_id [String] task list id
    # @return task lists
    def task_list(task_list_id)
      tasks_client = Google::Apis::TasksV1::TasksService.new
      tasks_client.authorization = @credentials
      return tasks_client.get_tasklist(task_list_id)
    end
    # Get all tasks from a given task list
    # @return tasks
    def tasks(task_list_id,show_completed = false)
      tasks_client = Google::Apis::TasksV1::TasksService.new
      tasks_client.authorization = @credentials
      return tasks_client.list_tasks(task_list_id,show_completed: show_completed, show_hidden: true)
    end
    # Get a single task from a given task list
    # @return task
    def task(task_id)
      tasks_client = Google::Apis::TasksV1::TasksService.new
      tasks_client.authorization = @credentials
      return tasks_client.get_task("@default",task_id)
    end
    # Insert a new task list
    # @param task_list_info [Hash] information for new task list, ie: title: "title"
    def new_task_list(**task_list_info)
      task_list_data = Google::Apis::TasksV1::TaskList.new
      task_list_info.keys.each do |key|
        task_list_data.instance_variable_set("@#{key.to_s}".to_sym, task_list_info[key])
      end
      tasks_client = Google::Apis::TasksV1::TasksService.new
      tasks_client.authorization = @credentials
      tasks_client.insert_tasklist(task_list_data)
    end
    # Insert a new task
    # @param task_list_id [String] task list id
    # @param task_info [Hash] information for new task, ie: title: "title"
    def new_task(task_list_id,**task_info)
      task_data = Google::Apis::TasksV1::Task.new
      task_info.keys.each do |key|
        task_data.instance_variable_set("@#{key.to_s}".to_sym, task_info[key])
      end
      tasks_client = Google::Apis::TasksV1::TasksService.new
      tasks_client.authorization = @credentials
      if task_data.parent
        #create with a parent
        tasks_client.insert_task(task_list_id,task_data,parent:task_data.parent)
      else
        #create at top level
        tasks_client.insert_task(task_list_id,task_data)
      end
    end
    # update a task list
    # @param task_list_id [String] task list id
    # @param task_list_info [Hash] information for new task, ie: title: "title"
    def update_task_list(task_list_id,**task_list_info)
      google = Deed::Google_api.new
      task_list_data = google.task_list(task_list_id)
      task_list_data.update!(task_list_info)
      tasks_client = Google::Apis::TasksV1::TasksService.new
      tasks_client.authorization = @credentials
      tasks_client.update_tasklist(task_list_id,task_list_data)
    end
    # update a task
    # @param task_list_id [String] task list id
    # @param task_id [String] task id
    # @param task_list_info [Hash] information for new task, ie: title: "title"
    def update_task(task_id,**task_info)
      google = Deed::Google_api.new
      task_data = google.task(task_list_id,task_id)
      task_data.update!(task_info)
      tasks_client = Google::Apis::TasksV1::TasksService.new
      tasks_client.authorization = @credentials
      tasks_client.update_task("@default",task_id,task_data)
    end
    # delete a task
    # @param task_list_id [String] task list id
    # @param task_id [String] task id
    def delete_task(task_id)
      tasks_client = Google::Apis::TasksV1::TasksService.new
      tasks_client.authorization = @credentials
      tasks_client.delete_task("@default",task_id)
    end
  end
end
