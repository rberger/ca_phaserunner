require 'gli'
require 'json'
require 'pp'

module Phaserunner

  class Cli
    attr_reader :modbus
    attr_reader :dict
    attr_reader :loop
    attr_reader :phaserunnerOutFd

    include GLI::App

    def main
      program_desc 'Read values from the Grin PhaseRunner Controller for logging'

      version Phaserunner::VERSION

      subcommand_option_handling :normal
      arguments :strict
      sort_help :manually

      desc 'Serial (USB) device'
      default_value '/dev/ttyUSB0'
      arg 'tty'
      flag [:t, :tty]

      desc 'Serial port baudrate'
      default_value 115200
      arg 'baudrate'
      flag [:b, :baudrate]

      desc 'Modbus slave ID'
      default_value 1
      arg 'slave_id'
      flag [:s, :slave_id]

      desc 'Path to json file that contains Grin Modbus Dictionary'
      default_value Modbus.default_file_path
      arg 'dictionary_file'
      flag [:d, :dictionary_file]

      desc 'Loop the command n times'
      default_value 10
      arg 'loop', :optional
      flag [:l, :loop], type: Integer
      # flag [:l, :loop], :desc => 'Loop the command n times', :type => Integer

      desc 'Read a single or multiple adjacent registers from and address'
      arg_name 'register_address'
      command :read_register do |read_register|
        read_register.desc 'Number of registers to read starting at the Arg Address'
        read_register.default_value 1
        read_register.flag [:c, :count]

        read_register.arg 'address'
        read_register.action do |global_options, options, args|
          address = args[0].to_i
          count = args[1].to_i
          node = dict[address]
          puts modbus.range_address_header(address, count).join(",")
          (0..loop).each do |i|
            puts modbus.read_raw_range(address, count).join(",")
          end
        end
      end

      desc 'Read a range plus bulk sparse set of registers with multiple addresses'
      command :read_bulk do |read_bulk|
        read_bulk.action do |global_options, options, args|
          start_address = 258
          count = 12
          misc_addresses =[277,334]
          header = modbus.bulk_log_header(start_address, count, misc_addresses)
          data = modbus.bulk_log_data(start_address, count, misc_addresses)

          hdr = %W(Timestamp,#{header.join(",")})
          puts hdr
          phaserunnerOutFd.puts hdr

          (0..loop).each do |i| 
            str = %W(#{Time.now.utc.round(10).iso8601(6)},#{data.join(",")})
            puts str
            phaserunnerOutFd.puts str
            sleep 0.2
          end
        end
      end

      pre do |global, command, options, args|
        # Pre logic here
        # Return true to proceed; false to abort and not call the
        # chosen command
        # Use skips_pre before a command to skip this block
        # on that command only
        @modbus = Modbus.new(global)
        @dict = @modbus.dict
        @loop = global[:loop]
        @phaserunnerOutFd = File.open("phaserunner.#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.csv", 'w')
      end

      post do |global,command,options,args|
        # Post logic here
        # Use skips_post before a command to skip this
        # block on that command only
      end

      on_error do |exception|
        # Error logic here
        # return false to skip default error handling
        true
      end

      exit run(ARGV)
    end
  end
end
