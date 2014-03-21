require 'digest/md5'
require 'erb'
require 'yaml'

class FileUploader
  def self.upload(file, options)
    self.new(options).process_upload(file)
  end

  def initialize(options)
    @notifier_path = options[:notifier_path] || "#{File.dirname(File.expand_path(__FILE__))}/../../resources/terminal-notifier"
    @config = YAML.load_file(options[:config_file])
    case @config['upload']['type']
    when "eval"
      require File.expand_path(File.dirname(__FILE__) + '/uploaders/eval_uploader')
      @uploader = EvalUploader.new(@config)
    when "scp"
      require File.expand_path(File.dirname(__FILE__) + '/uploaders/scp_uploader')
      @uploader = ScpUploader.new(@config)
    when "imgur"
      require File.expand_path(File.dirname(__FILE__) + '/uploaders/imgur_uploader')
      @uploader = ImgurUploader.new
    when "imageshack"
      require File.expand_path(File.dirname(__FILE__) + '/uploaders/imageshack_uploader')
      @uploader = ImageshackUploader.new(@config)
    else
      raise "Invalid Type"
    end
  rescue
    notify "Unable to load config file"
    raise "Unable to load config file"
  end

  def pbcopy(str)
    system "ruby -e \"print '#{str}'\" | pbcopy"
    # I prefer the following method but it was being intermitant about actually
    # coping to the clipboard.
    #IO.popen('pbcopy','w+') do |pbc|
    #  pbc.print str
    #end
  rescue
    raise "Copy to clipboard failed"
  end

  def process_upload(file)
    notify("Processing upload…", "", "captured-uploading")
    @uploader.upload(file)
    remote_path = @uploader.url
    puts "Uploaded '#{file}' to '#{remote_path}'"
    pbcopy remote_path
    notify("Upload succeeded. Paste the URL from the clipboard or click here to view.", remote_path)
    History.append(file, remote_path)
  rescue => e
    puts e
    puts e.backtrace
    notify(e)
  end

  def notify(message, url = "", group = "captured")
    puts "grr: #{message}"
    if File.exists? @notifier_path
      raise "Notifier Failed" unless system("#{@notifier_path} -title 'Captured' -message '#{message}' -open '#{url}' -group '#{group}' -remove captured-uploading")
    end
  rescue
    puts "Notify Error"
  end
end
