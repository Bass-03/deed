require "google_api"
require "deed"
require "chronic"
require "rainbow"

class Config
  @deed_config = Deed::Config.new
  @config_file = @deed_config.config_file
  @config_path = @deed_config.config_path
  # Obtain confiiguration data from config file
  def self.data
    @config_file
  end
  # Open config file on default editor
  def self.open_file
    @deed_config.open_file
  end
  # Make sure google's keys are there
  # @param print [Boolean] print messages
  # @return google client
  def self.check_google(print_it = true)
      if !File.file? "#{@config_path}/client_id.json"
        STDOUT.puts "Missing OAuth2 keys, you need the #{@config_path}/client_id.json file"
        STDOUT.puts "Get te file from google's API Console, it needs access to Tasks only"
        STDOUT.puts "https://developers.google.com/api-client-library/ruby/guide/aaa_apikeys"
        exit
      end
      #Check Google is authorized
      begin
        google = Deed::Google_api.new
      rescue Exception => e
        STDOUT.puts e.message
        STDOUT.puts "deleting tokens.yaml as measure"
        system "rm #{@config_path}/tokens.yaml"
        STDOUT.puts "try checking the credentials if error persists"
        exit
      end
      STDOUT.puts "Google credentian expires at: " + google.credentials.expires_at.to_s if print_it
      STDOUT.puts "Google Checked, all ok" if print_it
      return google
  end
  # Store new data on the config file
  def self.set_value key,value
    @deed_config.set_value key,value
  end
end

class Helper
  # catch errors
  # @return block result or error object
  def self.catch_error(&block)
    begin
      return block.call
    rescue Exception => e
      return e
    end
  end
  # Check if current task, list and default list still exist
  def self.check_config_tasks(google_client)
    current_task = catch_error {google_client.task("@default",Config.data[:current_task][:id])}
    current_list = catch_error {google_client.task_list(Config.data[:current_list][:id])}
    default_list = catch_error {google_client.task_list(Config.data[:default_list][:id])}
    #set value to nil if the response is an error
    Config.set_value("current_task",nil) if current_task.kind_of? Exception
    Config.set_value("current_list",nil) if current_list.kind_of? Exception
    Config.set_value("default_list",nil) if default_list.kind_of? Exception
  end
  # parse natural language date to rfc3339
  # @param date_string [String] natural language date
  # @return formated date string
  def self.date_parse(date_string)
    Chronic.parse(date_string).to_datetime.rfc3339
  end
  # Print a message
  # @param text [String] text to print
  # @param tasks [Google:Task] tasks to print
  # @param doing [Boolean] Print only the current task
  def self.print_message(text)
    colors = Config.data[:colors]
    STDOUT.puts Rainbow(text).color(colors[:message].to_sym).bright
  end
  # pretty print a lists
  # @param listName [String] list title to print
  def self.print_list_selection(lists)
    lists.each_with_index do |list,index|
      colors = Config.data[:colors]
      STDOUT.printf "%s",Rainbow(index.to_s + " " * lists.count.to_s.size).color(colors[:count].to_sym).bright
      STDOUT.printf "%s",Rainbow("|").color(colors[:separator].to_sym).bright #separator
      STDOUT.printf "%s",Rainbow(list.title).color(colors[:list].to_sym)
      STDOUT.printf "\n"
    end
  end
  #print tasks for selection
  def self.print_task_selection
  end
  # pretty print a list of tasks
  # @param listName [String] list title to print
  # @param tasks [Google:Task] tasks to print
  # @param doing [Boolean] Print only the current task
  # @return last task index
  def self.pretty_print_tasks(listName,tasks=[],count_start = 0,doing = false)
    # get colors from config
    current_task = Config.data[:current_task]
    colors = Config.data[:colors]
    #Print list title
    STDOUT.printf "%s",Rainbow(listName).color(colors[:list].to_sym).bright.underline
    STDOUT.printf "\n"
    # if no tasks on list
    if !tasks
      print_message("No tasks on this list") #separator"No tasks on this list"
    else
      tasks.each do |task|
        task = task.to_h #make sure task is a hash
        # Print spaces needed on count for all the digits is hsa
        print Rainbow(STDOUT.printf("%4d", count_start)).color(colors[:count].to_sym).bright
        STDOUT.printf "%s",Rainbow("|").color(colors[:separator].to_sym).bright #separator
        #date shoud always have the same lenght
        due_date = task[:due] ? task[:due].strftime("%b %d") : "      "
        STDOUT.printf "%s",Rainbow(due_date).color(colors[:due_date].to_sym).bright
        STDOUT.printf "%s",Rainbow("|").color(colors[:separator].to_sym).bright #separator
        #status,
        status = task[:status] == "completed" ? " (X) " : " ( ) "
        STDOUT.printf "%s",Rainbow(status).color(colors[:status].to_sym).bright
        # task color depends on doing and status
        task_color = nil
        if current_task
          task_color = colors[:doing_task] if task[:id] == current_task[:id]
        end
        #defailts to task color
        task_color = colors[:task] if !task_color
        subtask_arrow = task[:parent] ? "-> " : ""
        STDOUT.printf "%s",Rainbow(subtask_arrow + task[:title]).color(task_color.to_sym).bright
        STDOUT.printf "\n"
        if task[:notes]
          #Start comment at tab distance
          STDOUT.printf "\t%s", Rainbow(task[:notes]).color(colors[:notes].to_sym).gsub("\n","\n\t")
          STDOUT.printf "\n"
        end
        count_start += 1
      end
    end
    print "\n"
    return count_start
  end
  #Update config file with the selcted task and task_list
  # @param selected_list [Google::TaskList] new current task list
  # @param selected_task [Google::List] new current task
  def self.update_selected(selected_list,selected_task)
    #Fill hashes
    selected_task = { id: selected_task.id,
                      title:selected_task.title,
                      updated: selected_task.updated,
                      parent: selected_task.parent,
                      notes: selected_task.notes,
                      status: selected_task.status,
                      due: selected_task.due,
                      completed: selected_task.completed,
                      deleted: selected_task.deleted,
                      hidden: selected_task.hidden
                    }
    selected_list ={  id: selected_list.id,
                      title: selected_list.title,
                      updated: selected_list.updated
                    }

    Config.set_value("current_task",selected_task)
    Config.set_value("current_list",selected_list)
  end

  # Check everything needed for deed works
  # @return google client
  def self.pre_checks
    #check config file and google client's config
    google = Config.check_google(false)  #Do not proint messages, unless error happens
    # Check if default and current tasks/lists exist
    self.check_config_tasks(google)
    # Check current list and task
    if Config.data[:current_task] and Config.data[:current_task]
      current_list = google.task_list(Config.data[:current_list][:id])
      current_task = google.task(Config.data[:current_task][:id])
      # Update current data in config file
      self.update_selected(current_list,current_task)
    end
    return google
  end
end
