require 'shellwords'
require 'travis/build/appliances/base'
require 'travis/build/helpers/template'

module Travis
  module Build
    module Appliances
      class DebugTools < Base
        include Template
        TEMPLATES_PATH = File.expand_path('templates', __FILE__.sub('.rb', ''))

        TMATE_HOST_SETTINGS = case ENV['RACK_ENV']
        when 'staging'
          {
            :host              => "tmate-staging.travisci.net",
            :rsa_fingerprint   => "8e:4a:6b:76:fe:6b:50:4d:21:81:1b:da:c9:23:d0:9e",
            :ecdsa_fingerprint => "0a:77:9e:20:2b:f8:a9:55:e5:a4:db:d6:7f:d2:59:68",
          }
        when 'production'
          {
            :host              => "tmate-production.travisci.net",
            :rsa_fingerprint   => "a5:77:39:bb:8b:10:b6:5c:23:ef:ed:a4:84:94:fe:a1",
            :ecdsa_fingerprint => "b3:5f:1f:41:cf:c8:75:22:dc:a0:93:0a:78:84:ba:62",
          }
        end

        def enabled?
          ENV['TRAVIS_ENABLE_DEBUG_TOOLS'] == '1'
        end

        def apply
          enabled? ? apply_enabled : apply_disabled
        end

        def apply_enabled
          sh.raw 'function travis_debug_install() {'
            sh.echo "Setting up debug tools.", ansi: :yellow
            sh.mkdir install_dir, echo: false, recursive: true
            sh.cd install_dir, echo: false, stack: true

            sh.if "$(uname) = 'Linux'" do
              sh.cmd "wget -q -O tmate.tar.gz #{static_build_linux_url}", echo: false, retry: true
              sh.cmd "tar --strip-components=1 -xf tmate.tar.gz", echo: false
            end
            sh.else do
              sh.echo "We are setting up the debug environment. This may take a while..."
              sh.cmd "brew update &> /dev/null", echo: false, retry: true
              sh.cmd "brew install tmate &> /dev/null", echo: false, retry: true
            end

            sh.file "travis_debug.sh", template('travis_debug.sh')
            sh.chmod '+x', "travis_debug.sh", echo: false

            sh.mkdir "#{HOME_DIR}/.ssh", echo: false, recursive: true
            sh.cmd "cat /dev/zero | ssh-keygen -q -f #{HOME_DIR}/.ssh/tmate -N '' &> /dev/null", echo: false
            sh.file "#{HOME_DIR}/.tmate.conf", template("tmate.conf",
              identity: "#{HOME_DIR}/.ssh/tmate", host_settings: TMATE_HOST_SETTINGS)
            sh.export 'PATH', "${PATH}:#{install_dir}", echo: false

            sh.cd :back, echo: false, stack: true
          sh.raw '}'

          sh.raw 'function travis_debug() {'
            sh.raw 'travis_debug_install'
            sh.echo "Preparing debug sessions."
            sh.raw 'TRAVIS_CMD=travis_debug'
            sh.raw 'travis_debug.sh "$@"'
          sh.raw '}'
        end

        def apply_disabled
          sh.raw 'function travis_debug() {'
            sh.echo "The debug environment is not available. Please contact support.", ansi: :red
            sh.raw "false"
          sh.raw '}'
        end

        private
          def install_dir
            "#{HOME_DIR}/.debug"
          end

          # XXX the following does not apply to OSX

          def version
            "2.2.0"
          end

          def static_build_linux_url
            "https://github.com/tmate-io/tmate/releases/download/#{version}/tmate-#{version}-static-linux-amd64.tar.gz"
          end
      end
    end
  end
end
