# Copyright (c) 2013 Red Hat
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#
# -= Systems CSV =-
#
# Columns
#   Name
#     - System name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   MAC Address
#     - MAC address
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "FF:FF:FF:FF:FF:%02x" -> "FF:FF:FF:FF:FF:0A"
#     - Warning: be sure to keep count below 255 or MAC hex will exceed limit
#

require 'hammer_cli'
require 'katello_api'
require 'foreman_api'
require 'json'
require 'csv'
require 'uri'

module HammerCLICsv
  class SystemsCommand < BaseCommand

    ORGANIZATION = 'Organization'
    ENVIRONMENT = 'Environment'
    CONTENTVIEW = 'Content View'
    VIRTUAL = 'Virtual'
    HOST = 'Host'
    OPERATINGSYSTEM = 'OS'
    ARCHITECTURE = 'Arch'
    SOCKETS = 'Sockets'
    RAM = 'RAM'
    CORES = 'Cores'
    SLA = 'SLA'
    PRODUCTS = 'Products'
    SUBSCRIPTIONS = 'Subscriptions'

    def export
      # TODO
    end

    def import
      @existing = {}

      #puts "ENVIRONMENT #{katello_environment('ACME_Corporation', :name => 'Library')}"
      #puts "CONTENTVIEW #{katello_contentview('ACME_Corporation', :name => 'Default_Organization_View')}"

      thread_import do |line|
        create_systems_from_csv(line)
      end
    end

    def create_systems_from_csv(line)

      @k_system_api.index({'organization_id' => line[ORGANIZATION], 'page_size' => 999999, 'paged' => true}, HEADERS)[0]['results'].each do |system|
        @existing[line[ORGANIZATION]] ||= {}
        @existing[line[ORGANIZATION]][system['name']] = system['id'] if system
      end

      facts = {}
      facts['cpu.core(s)_per_socket'] = line[CORES]
      facts['cpu.cpu_socket(s)'] = line[SOCKETS]
      facts['memory.memtotal'] = line[RAM]
      facts['uname.machine'] = line[ARCHITECTURE]
      if line[OPERATINGSYSTEM].index(' ')
        (facts['distribution.name'], facts['distribution.version']) = line[OPERATINGSYSTEM].split(' ')
      else
        (facts['distribution.name'], facts['distribution.version']) = ['RHEL', line[OPERATINGSYSTEM]]
      end

      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        if !@existing.include? name
          print "Creating system '#{name}'..." if verbose?
          @k_system_api.create({
                                 'name' => name,
                                 'organization_id' => 'ACME_Corporation', #foreman_organization(:name => line[ORGANIZATION]),
                                 'environment_id' => 1, #katello_environment(:name => line[ENVIRONMENT]),
                                 'content_view_id' => 1, #katello_contentview(:name => line[CONTENTVIEW]),
                                 'facts' => facts,
                                 'cp_type' => 'system'
                           }, HEADERS)
          print "done\n" if verbose?
        else
          print "Updating host '#{name}'..." if verbose?
=begin
          @k_system_api.update({
                               'id' => @existing[name],
                               'host' => {
                                 'name' => name,
                                 'mac' => namify(line[MACADDRESS], number),
                                 'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                                 'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
                                 'operatingsystem_id' => foreman_operatingsystem(:name => line[OPERATINGSYSTEM]),
                                 'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
                                 'architecture_id' => foreman_architecture(:name => line[ARCHITECTURE]),
                                 'domain_id' => foreman_domain(:name => line[DOMAIN]),
                                 'ptable_id' => foreman_partitiontable(:name => line[PARTITIONTABLE])
                               }
                             }, HEADERS)
=end
          print "done\n" if verbose?
        end
      end
    rescue RuntimeError => e
      raise RuntimeError.new("#{e}\n       #{line}")
    end
  end

  HammerCLI::MainCommand.subcommand("csv:systems", "import/export systems", HammerCLICsv::SystemsCommand)
end