require 'vcap/config'
require 'vcap/common'

class StagingPlugin
end

class StagingPlugin::Config < VCAP::Config
  define_schema do
    {
      "source_dir"             => String,        # Location of the unstaged app
      "dest_dir"               => String,        # Where to place the staged app
      optional("manifest_dir") => String,

      optional("secure_user") => {               # Drop privs to this user
        "uid"           => Integer,
        optional("gid") => Integer
      },

      optional("environment") => {               # This is misnamed, but it is called this
        "services"  => [Hash],                   # throughout the existing staging code. We use
        "framework" => String,                   # it to maintain consistency.
        "runtime"   => String,
        "resources" => {
          "memory" => Integer,
          "disk"   => Integer,
          "fds"    => Integer
        }
      }
    }
  end

  def self.from_file(cfg_filename)
    config = super(cfg_filename, false)
    config = VCAP.symbolize_keys(config)

    # Support code expects symbolized keys for service information
    conf_env = config[:environment]
    if conf_env and conf_env[:services]
      conf_env[:services] = conf_env[:services].map do |svc|
        VCAP.symbolize_keys(svc)
      end
    end

    config
  end
end
