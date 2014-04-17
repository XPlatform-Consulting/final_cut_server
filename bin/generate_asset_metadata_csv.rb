#!/usr/bin/env ruby
#
# A utility script to output the metadata of either an asset or a production's assets to a csv file.
#
# NOTE: An "ADDRESS" field is added to the metadata with the address of the asset as the value
require 'optparse'

options = { }
op = OptionParser.new
op.on('--production-id ID', 'A production id of a production to output the asset information for.') { |v| options[:production_id] = v }
op.on('--asset-id ID', 'An asset id of an asset to output') { |v| options[:asset_id] = v }
op.on('--csv-file-output FILEPATH', '')  { |v| options[:csv_file_output_path] = v }
op.on('--log-level INTEGER', Integer, 'Logging Level. 0 = DEBUG. Default = 1') { |v| options[:log_level] = v }
op.parse!

@production_id = options[:production_id]
@asset_id = options[:asset_id]
@csv_file_output_path = options[:csv_file_output_path]
@log_level = options[:log_level] || 1

def production_id; @production_id end
def asset_id; @asset_id end
def csv_file_output_path; @csv_file_output_path end
def log_level; @log_level end

abort("production id OR asset id argument is required.\n\n#{op}") unless production_id or asset_id or (production_id and asset_id)
abort("csv file output argument is required.\n\n#{op}") unless csv_file_output_path
########################################################################################################################


require 'cgi'
require 'net/ssh'
require 'shellwords'
module FinalCutServer

  class Client
=begin
    Commands:

      analyze [--force] [--fcp] <asset entity_address>
      clone [ --name <name> ] <permission set|production entity_address>
      count [--recurse] <container_address>
      getmd [--xml] <entity_address>
      list_child_links [ --xml --linktype <n> --linkancestors ] <entity_address>
      list_groups [ --xml ]
      list_mdgroups [ --xml --action <mdgroupaction> --parent --allmdgroups --asset_type <type> ] <entity_address|container_address>
      list_parent_links [ --xml --linktype <n> ] <entity_address>
      search [ --verbose --noheader --mdonly --tabdelim --xml --limit <n> --depth <n> --xmlcrit --crit <str> --ctxaddr <addr> --dirs --linkparentaddr <production entity_address> --linkparentrecursive ] <container_address|directory rep_address>

    Commands requiring fcsvr_client to be run as root:

      archive <asset entity_address> <device entity_address>
      create [--type <entity_type> --linkparentaddr <entity_address> --linkparentlinktype <type> --xml] <container_address> [<metadata_list>|<xml_file>]
      createasset [--background --projaddr <production entity_address>] <type> <file rep_address> [<metadata_list>]
      delete [ --confirm --use_lds --asset_only --erase_children --xml ] <entity_address>
      dump_state
      flush_response_queue
      load_templates [--noclobber] [<template_xml_file>]
      make_link [--linktype <id> --movelink] <parent entity_address> <child entity_address>
      revert --version <number> <asset entity_address>
      restore <asset entity_address>
      set_device_templates [--all --clear] <device entity_address> [<template address list>]
      setmd [--xml] <entity_address> [<metadata_list>|<xml_file>]
      subscribe [ --verbose --noheader --limit <n> --depth <n> --crit <str> --events <str> --responseid <id> ] <container_address>
      upload [ --projaddr <production entity_address> --background ] <directory rep_address> <file> <mdfile>
=end

    DEFAULT_EXECUTABLE_PATH = '/Library/Application Support/Final Cut Server/Final Cut Server.bundle/Contents/MacOS/fcsvr_client'
    DEFAULT_USE_SUDO = true
    DEFAULT_USE_SSH = true

    class << self
      attr_accessor :logger
      attr_accessor :ssh_settings, :response, :use_ssh, :use_sudo
      #attr_accessor :proxy_device_address, :archive_device_address
      attr_accessor :fcsvr_client_executable

      def logger
        @logger ||= Logger.new(STDOUT)
      end # self.logger

      def fcsvr_client_executable
        @fcsvr_client_executable ||= DEFAULT_EXECUTABLE_PATH.shellescape
      end # self.fcsvr_client_executable

      def fcsvr_client_executable=(path)
        @fcsvr_client_executable = path.shellescape
      end # fcsvr_client_executable=

      def transform_options(options)
        args = []
        options.each do |key, value|
          next if value == false
          args << "--#{key.to_s}"
          args << value unless value == true
        end
        args
      end # transform_options

      def execute(command_line)
        logger.debug { "Executing Command Line: #{command_line}" }
        if use_ssh and ssh_settings.is_a? Hash and ssh_settings.fetch(:hostname, false)
          output = execute_ssh command_line
        else
          output = execute_sh command_line
        end
        output = output.to_s.chomp.strip rescue output
        logger.debug { "Response: #{output}" }
        return output
      end # execute

      def execute_sh(command_line)
        @response = `#{command_line}`
      end # execute_sh

      def execute_ssh(command_line)
        ssh = Net::SSH.start(@ssh_settings[:hostname], @ssh_settings[:username], :password => @ssh_settings[:password])
        @response = ssh.exec!(command_line)
        ssh.close
        @response
      end # execute_ssh

      def fcsvr_client_search(xml, container_address, params = { })
        default_params = { :xml => true, :xmlcrit => true }
        args = transform_options(default_params.merge(params)).join(' ')
        execute "echo \"#{xml}\" | #{fcsvr_client_executable} search #{args} #{container_address}"
      end # fcsvr_client_search

      def fcsvr_client(command_line)
        sudo = (@use_sudo and %w(archive create createasset delete dump_state flush_response_queue load_templates make_link
                  revert restore set_device_template setmd subscribe upload).include?(command_line.split(' ', 2).first)) ? 'sudo ' : ''

        execute "#{sudo}#{fcsvr_client_executable} #{command_line}"
      end # fcsvr_client
    end # << self

    self.use_sudo = DEFAULT_USE_SUDO

    self.use_ssh = DEFAULT_USE_SSH

    #self.proxy_device_address = '/dev/1'
    #self.archive_device_address = nil
  end # client


  require 'rexml/document'
  require 'rexml/formatters/pretty'
  class Entity

    class << self
      attr_accessor :logger

      def logger
        @logger ||= Client.logger
      end # self.logger
    end

    # @param [String, Integer] id Either the numerical id or the address of the entity
    # @return [Object]
    def self.get id, params = { }
      self.new id, params
    end # self.get

    # @param [String] address
    # @param [Hash] params
    def self.delete address, params = { }
      default_params = { :xml => true }
      args = transform_options(default_params.merge(params)).join(' ')
      command_line = "delete #{args} #{address}"
      response = Client::fcsvr_client(command_line)
    end # self.delete

    def self.search_xml xml, params = { }
      container_address = params.delete(:container_address) { "/#{get_root_container_name}" }
      results = Client.fcsvr_client_search xml, container_address, params
      REXML::Document.new results
    end # search

    def self.search params = { }
      container_address = params.delete(:container_address) { "/#{get_root_container_name}" }
      default_params = { :xml => true }
      args = Client.transform_options(default_params.merge(params)).join(' ')
      command_line = "search #{args} #{container_address}"
      results = Client.fcsvr_client(command_line)
      REXML::Document.new results
    end # search

    # Uses the current object's name to determine the root container name
    def self.get_root_container_name
      # { 'Asset' => 'asset', 'Device' => 'dev', 'Project' => }
      lc_name = self.name.split('::').last.downcase
      { 'device' => 'dev' }.fetch(lc_name, lc_name)
    end

    def self.parse_metadata_xml_values(values)
      metadata_out = { }
      values.each { |value|
        next unless value and value.kind_of? REXML::Element
        metadata_out[value.attributes['id']] = value.elements[1].text
      }
      metadata_out
    end

    def parse_metadata_xml_values(values)
      metadata_out = { }
      values.each { |value|
        next unless value and value.kind_of? REXML::Element
        metadata_out[value.attributes['id']] = value.elements[1].text
      }
      metadata_out
    end

    def self.parse_search_results_document(xml_document_in)
      results = [ ]
      xml_document_in.root.elements.each { |value|
        address = value.elements[4].elements[1].text
        results << address
        #metadata_xml = value.elements[2].elements['values']
        #logger.debug { "#{address} #{parse_metadata_xml_values metadata_xml}" }
      }
      results
    end

    attr_accessor :id, :metadata_xml_raw, :metadata_xml_document, :metadata

    def get_root_container_name
      lc_name = self.class.name.split('::').last.downcase
      { 'device' => 'dev' }.fetch(lc_name, lc_name)
    end # get_root_container_name

    def logger
      Client.logger
    end # logger

    def initialize(id, params = { })
      id = id.scan(/\d+/).first if id.is_a? String
      @id = id
      initialize_metadata if params.fetch(:with_metadata, true)
      initialize_attributes if params.fetch(:with_attributes, true)
    end # initialize

    def address
      @address ||= "/#{get_root_container_name}/#{@id}"
    end # address

    def delete(address_to_delete = address, params = { })
      self.delete address_to_delete, params
    end # delete

    def metadata_xml_raw
      @metadata_xml_raw ||= Client::fcsvr_client("getmd --xml #{address}")
    end # metadata_xml_raw

    # @param [Hash] metadata
    def set_metadata(metadata)
      command_line = "setmd #{address}"
      metadata_string = metadata.each { |k,v| val = v.is_a?(String) ? "'#{v}'" : v; command_line.concat(" #{k.to_s.upcase}=#{val}")}
      response = Client::fcsvr_client(command_line)
    end # set_metadata

    def metadata_xml_document
      @metadata_xml_document ||= REXML::Document.new(metadata_xml_raw)
    end # metadata_xml_document

    def initialize_metadata(metadata_in = metadata_xml_document)
      @metadata = self.parse_metadata_xml_values(metadata_xml_document.root.elements['values'])
    end # initialize_metadata

    def initialize_attributes
      # To be implemented in child classes
    end # initialize_attributes

    # @param [String] address
    def determine_file_system_path_from_container_address(address)
      logger.debug { "Determining File System Path from Container Address. #{address}" }
      file_id, file_name = File.basename(address).split('_', 2)
      file_id = file_id.to_i
      logger.debug { "\tFile ID: #{file_id} File Name: #{file_name}" }
      relative_file_system_path = sprintf("/%02x/%02x/%016x/%s", ((file_id >>8) & 0xff), ((file_id >>16) & 0xff), file_id, file_name)
      logger.debug { "\tRelative File System Path: #{relative_file_system_path}" }

      relative_file_system_path
    end # determine_file_system_path_from_container_address

    # Creates a hash consisting of an objects instance variables
    #
    # @param [Boolean] keys_to_symbols Determines if the hash keys will be returned as strings or symbols
    # @return [Hash]
    def to_hash(keys_to_symbols = false, recursive = true)
      Hash[self.instance_variables.map { |k|
        key = k.to_s.delete('@')
        if key == 'metadata_xml_document'
          value = nil
        else
          value = self.instance_variable_get(k)
          value = value.to_hash if ((recursive == true) and value.respond_to?(:to_hash))
        end
        key.to_sym if keys_to_symbols
        [ key, value ]
      }]
    end # to_hash

  end # Entity

  class Device < Entity

    def self.get_by_name(device_name, params = { })
      # THE SPACE IN THE GREP STRING IS IMPORTANT
      devices_text_raw = Client::fcsvr_client("search /dev | grep '#{device_name} '")
      device_id = devices_text_raw.match(/\/dev\/(\d+)\s+/).to_s.rstrip.split('/').last
      get device_id, params
    end

    def name
      @name ||= metadata.fetch('DEVICE_NAME', nil)
    end # name

    def address
      @address ||= "/dev/#{@id}"
    end # address

    def type
      @type ||= metadata.fetch('DEVICE_TYPE', nil)
    end # type

    def root_path
      @root_path ||= metadata.fetch('DEV_ROOT_PATH', nil)
    end # root_path

  end # Device

  class Asset < Entity

    attr_accessor :device,

                  :clip_representation_absolute_file_system_path,
                  :thumbnail_representation_absolute_file_system_path,
                  :poster_frame_representation_absolute_file_system_path

    def initialize_device
      @device = Device.get_by_name @metadata['CUST_DEVICE']
    end # set_device

    def process_parent_link(linktype)
      logger.debug { "Processing Parent Link #{linktype}" }
      parent_detail_text = Client::fcsvr_client("list_parent_links --linktype #{linktype} #{address}")
      return { } if parent_detail_text.empty?
      parent_address = parent_detail_text.lines.first.chomp.split(':', 2).last.strip
      parent_address.match(/^(\/dev\/\d*)\/(.*)/)

      parent_device = Device.get_by_name $1
      parent_relative_path = $2
      parent_relative_path = determine_file_system_path_from_container_address(parent_address) if parent_device.type == 'contentbase'
      parent_relative_path = CGI.unescape(parent_relative_path)

      parent_device_root_path = parent_device.root_path || ''
      absolute_path = "#{parent_device_root_path}#{parent_device_root_path.end_with?('/') || parent_relative_path.start_with?('/') ? '' : '/'}#{parent_relative_path}"
      absolute_path = CGI.unescape(absolute_path)

      {
          :raw_text => parent_detail_text,
          :device   => parent_device,
          :address  => parent_address,
          :root     => parent_device.root_path,
          :relative => parent_relative_path,
          :absolute => absolute_path
      }
    end # process_parent_link

    def process_parent_links
      @primary_representation_absolute_file_system_path  = process_parent_link(2)[:absolute]
      @clip_proxy_absolute_file_system_path = process_parent_link(4)[:absolute]
      @thumbnail_file_absolute_system_path = process_parent_link(5)[:absolute]
      @poster_frame_absolute_file_system_path = process_parent_link(6)[:absolute]
      @archived_copy_absolute_file_system_path = process_parent_link(13)[:absolute] if (archive_status == 'offline')
    end # process_parent_links


    def initialize_attributes
      initialize_device
      process_parent_links
    end # set_attributes

    def archive_status
      @archive_status ||= metadata.fetch('ASSET_ARCHIVE_STATUS', '').to_s
    end # archive_status

    # @return [String]
    def location
      @location ||= metadata.fetch('CUST_LOCATION', '').to_s
    end # location

    # Returns the filename of the asset
    # @return [String]
    def filename
      @filename ||= metadata.fetch('PA_MD_CUST_FILENAME', '').to_s
    end # filename

    # @return [String]
    # Returns the path and filename of the asset
    def primary_representation_absolute_file_system_path
      @primary_representation_absolute_file_system_path
    end # primary_representation_absolute_file_system_path
    alias :full_file_system_path :primary_representation_absolute_file_system_path
    alias :full_path_on_file_system :primary_representation_absolute_file_system_path

    # @param [String] device_entity_address The address of the device to archive to.
    def archive(device_entity_address)

      # Asset already archive, task is SUCCESSFUL
      # { CODE = E_DUPLICATE, DESC = The asset is already offline, we can't archive it now, NODE = ["PmsTask_ArchiveAsset" 0x711bca90, ref=8, wref=6] lockToken=13001471 holding locks:(/asset/281923 RD token=13001471)(/asset/281923:analyse WR token=13001471)(/dev/30 RD token=13001471) taskState=4 dbqueue=0x7450dd64 (holds lock on db connection 2) needTrans inTrans, SRC_FILE = PmsTask_ArchiveAsset.C, SRC_LINE = 668 }
      #
      # These are all FAILURES
      # { CODE = E_FILE, DESC = Couldn't stat file: /Volumes/BACKUP/PRIMARY/TestContentBase.bundle/00/09/00000000000900aa/PWD.txt, ERRNO = 2, SRC_FILE = PmdTrait_LCBFile.C, SRC_LINE = 232, RETRY_ME = false, ERRSTR = No such file or directory }
      # { CODE = E_FILE, DESC = unable to stat directory: /Volumes/BACKUP/PRIMARY/ReadyForArchive.bundle, ERRNO = 2, SRC_FILE = PmdTrait_LCBDir.C, SRC_LINE = 387, RETRY_ME = false, ERRSTR = No such file or directory, ERROR_TYPE = ET_PERM }
      # { CODE = E_INVAL, DESC = Archive device is of unknown type, suspect configuration error, NODE = ["PmsTask_ArchiveAsset" 0x80b3c1f0, ref=7, wref=6] lockToken=13002732 holding locks:(/asset/281923 RD token=13002732)(/asset/281923:analyse WR token=13002732)(/dev/30 RD token=13002732) taskState=6 dbqueue=0x7450dda4 (holds lock on db connection 1) needTrans inTrans, SRC_FILE = PmsTask_ArchiveAsset.C, SRC_LINE = 717 }
      response = Client::fcsvr_client("archive #{address} #{device_entity_address}")
      return true if response.empty?

      # response = response[2..-3].split(', ').map { |v| v.split(" = ") } # Transform response string into hash
      response = Hash[*response[2..-3].split(/[,\s]{0,2}([A-Z_]{2,})\s=\s/).drop(1)] # Transform response string into hash
      return true if response['CODE'] == 'E_DUPLICATE'

      return response

    end # archive

    def restore
      response = Client::fcsvr_client("restore #{address}")
      return true if response.empty?
      return false
    end # restore

  end # Asset

  class Field < Entity

  end

  class Project < Entity

    def self.get_assets_as_xml_document(production_id)
      Asset.search(:linkparentaddr => "/project/#{production_id}")
    end


  end

end

########################################################################################################################

FinalCutServer::Client.logger.level = log_level if log_level

require 'pp'
require 'csv'

class Asset < FinalCutServer::Asset; end
class Device < FinalCutServer::Device; end
class Entity < FinalCutServer::Entity; end
class Project < FinalCutServer::Project; end


def parse_xml_values(values)
  metadata_out = { }
  values.each do |value|
    next unless value and value.kind_of? REXML::Element
    values = value.elements['values']
    metadata_out[value.attributes['id']] = values ? parse_xml_values(values) : value.elements[1].text
  end
  metadata_out
end

def asset_to_table(asset)
  metadata = { 'ADDRESS' => asset.address }
  metadata.merge!(asset.metadata)
  fields = metadata.keys
  table = [ fields ]
  table << fields.map { |field_name| metadata[field_name] }
  table
end

def assets_to_table(assets)
  fields = [ 'ADDRESS' ]
  assets_metadata = assets.map do |asset|
    metadata = asset['METADATA']
    fields = fields | metadata.keys
    metadata['ADDRESS'] = asset['ADDRESS']
    metadata
  end
  table = [ fields ]
  table = table + assets_metadata.map { |md| fields.map { |field_name| md[field_name] } }
  table
end

def assets_xml_doc_to_table(assets_xml_doc)
  assets = assets_xml_doc.root.elements.map { |v| parse_xml_values(v)  }
  assets_table = assets_to_table(assets)
  assets_table
end

def output_to_csv(data, destination_file_path)
  CSV.open(destination_file_path, 'w') { |writer| data.each { |row| writer << row } }
end

if production_id
  assets_xml_doc = Project.get_assets_as_xml_document(production_id)
  assets_table = assets_xml_doc_to_table(assets_xml_doc)
  output_to_csv(assets_table, csv_file_output_path)
else
  asset = Asset.get(asset_id, :with_attributes => false)
  asset_table = asset_to_table(asset)
  output_to_csv(asset_table, csv_file_output_path)
end

puts "Data output to file: '#{File.expand_path(csv_file_output_path)}'"