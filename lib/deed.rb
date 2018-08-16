require "deed/version"
require "json"

module Deed
  #Class to config the gem
  class Config
    attr_reader :config_path
    attr_reader :config_file
    def initialize(path = ENV["deed_path"])
      #Check if deed_path is set. It can be set in the bash profile too
      #set it in home folder if not set already
      path = ENV['HOME'] + "/.deed" if !path
      @config_path = path
      # check if config dir exists
      if !File.directory? @config_path
        Helper.print_message "Creating folder '#{@config_path}'"
        system "mkdir -p #{@config_path}"
      end
      #check if config file exists
      if !File.file? "#{@config_path}/config.json"
        Helper.print_message "creating config.json in #{@config_path}"
        system "touch #{@config_path}/config.json" #create config file
        #adding empty json to config.json
        baseConfig = {
          path: path,
          google_tasks: true,
          editor: "nano",
          current_task: nil,
          current_list: nil,
          default_list: nil,
          colors: {
              past_date: "indianred",
              due_date: "darkslategray",
              task: "silver",
              doing_task: "lawngreen",
              deleted_task: "black",
              status: "darkslateblue",
              separator: "green",
              count: "webgray",
              notes: "lightslategray",
              message: "lightslategray",
              list: "goldenrod"
          }
        }
        File.open(@config_path + "/config.json","w+"){|file| file.write(JSON.pretty_generate(baseConfig))}
      end

      file = File.read(path + "/config.json")
      @config_file = JSON.parse(file,{:symbolize_names => true})
    end
    # open file
    def open_file
      system "#{@config_file[:editor]} #{@config_path}/config.json"
    end
    # set configuration
    # @param var [String] Variable to set
    # @param value [String] value to set
    def set_value var,value
      @config_file[var.to_sym] = value
      File.open(@config_path + "/config.json", 'w') { |file| file.write(JSON.pretty_generate(@config_file)) }
    end
  end

end
