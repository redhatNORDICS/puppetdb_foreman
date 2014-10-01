#
# Copyright 2013 CERN, Switzerland
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


module PuppetdbForeman
  module HostExtensions
    extend ActiveSupport::Concern
    included do
      before_destroy :deactivate_host
      after_build :deactivate_host

      def deactivate_host
        logger.debug "Deactivating host #{name} in Puppetdb"
        return false unless configured?

        if enabled?
          begin
            uri = URI.parse(Setting[:puppetdb_address])
            req = Net::HTTP::Post.new(uri.path)
            req['Accept'] = 'application/json'
            req.body = 'payload={"command":"deactivate node","version":1,"payload":"\"'+name+'\""}'
            res             = Net::HTTP.new(uri.host, uri.port)
            res.use_ssl     = uri.scheme == 'https'
            if res.use_ssl?
              if Setting[:ssl_ca_file]
                res.ca_file = Setting[:ssl_ca_file]
                res.verify_mode = OpenSSL::SSL::VERIFY_PEER
              else
                res.verify_mode = OpenSSL::SSL::VERIFY_NONE
              end
              if Setting[:ssl_certificate] && Setting[:ssl_priv_key]
                res.cert = OpenSSL::X509::Certificate.new(File.read(Setting[:ssl_certificate]))
                res.key  = OpenSSL::PKey::RSA.new(File.read(Setting[:ssl_priv_key]), nil)
              end
            end
            res.start { |http| http.request(req) }
          rescue => e
            errors.add(:base, _("Could not deactivate host on PuppetDB: #{e}"))
          end
          errors.empty?
        end
      end

      private

      def configured?
        if enabled? && Setting[:puppetdb_address].blank?
          errors.add(:base, _("PuppetDB plugin is enabled but not configured. Please configure it before trying to delete a host."))
        end
        errors.empty?
      end

      def enabled?
        [true, 'true'].include? Setting[:puppetdb_enabled]
      end
    end
  end
end
