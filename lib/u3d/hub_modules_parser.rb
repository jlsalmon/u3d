# frozen_string_literal: true

## --- BEGIN LICENSE BLOCK ---
# Copyright (c) 2016-present WeWantToKnow AS
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
## --- END LICENSE BLOCK ---

require 'json'
require 'u3d/unity_versions'
require 'u3d/utils'
require 'u3d_core/helper'

module U3d
  module HubModulesParser
    class << self
      HUB_MODULES_NAME = '%<version>s-%<os>s-modules.json'

      def load_modules(version, os: U3dCore::Helper.operating_system, offline: false)
        path = modules_path(version, os)

        # force download if no hub file present
        download_modules(os: os) if !Utils.file_exists_not_empty?(path) && !offline

        unless Utils.file_exists_not_empty?(path)
          UI.verbose "No modules registered for UnityHub for version #{version}"
          # cached_versions.keys.map{|s| UnityVersionNumber.new(s)}
          # searching for closest version
          files = Dir.glob("#{default_modules_path}/*-#{os}-modules.json")

          vn = UnityVersionNumber.new(version)

          versions_and_paths = files.map do |p|
            v = File.basename(p).split('-')[0]
            [UnityVersionNumber.new(v), p]
          end
          # filtered by version major.minor.patch (same major & minor and patch higher or equal)
          versions_and_paths = versions_and_paths.select { |a| a[0].parts[0] == vn.parts[0] && a[0].parts[1] == vn.parts[1] && a[0].parts[2] >= vn.parts[2] }

          if versions_and_paths.empty?
            UI.info "No closest version from UnityHub found for version #{version}"
            return []
          end
          path = versions_and_paths.first[1]
        end

        return JSON.parse(File.read(path))
      end

      def download_modules(os: U3dCore::Helper.operating_system)
        url = UnityVersions.json_url_for(json_os(os))
        builds = UnityVersions.fetch_json(url, UnityVersions::UNITY_LATEST_JSON)
        builds.each { |build| write_modules(build, os) }
        return builds.map { |build| build['versions'] }
      end

      private

      def json_os(os)
        platform_versions = case os
                            when :win
                              UnityVersions::WindowsVersions
                            when :linux
                              UnityVersions::LinuxVersions
                            when :mac
                              UnityVersions::MacVersions
                            end

        return platform_versions::JSON_OS
      end

      def modules_path(version, os)
        file_name = format(HUB_MODULES_NAME, version: version, os: os)
        File.join(default_modules_path, file_name)
      end

      def default_modules_path
        File.join(U3dCore::Helper.data_path, 'unity_hub_modules')
      end

      def write_modules(build, os)
        path = modules_path(build['version'], os)
        Utils.ensure_dir(File.dirname(path))

        File.write(path, build['modules'].to_json)
      end
    end
  end
end
