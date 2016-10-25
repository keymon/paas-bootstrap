require 'singleton'
require 'open3'
require 'yaml'

module ManifestHelpers
  class Cache
    include Singleton
    attr_accessor :manifest_with_defaults
  end

  def manifest_with_defaults
    Cache.instance.manifest_with_defaults ||= load_default_manifest
  end

private

  def fake_env_vars
    ENV["AWS_ACCOUNT"] = "dev"
    ENV["CONCOURSE_INSTANCE_PROFILE"] = "concourse-build"
  end

  def load_default_manifest
    fake_env_vars
    output, error, status = Open3.capture3(
      [
        File.expand_path("../../../../shared/build_manifest.sh", __FILE__),
        File.expand_path("../../../concourse-base.yml", __FILE__),
        File.expand_path("../../fixtures/predefined-concourse-secrets.yml", __FILE__),
        File.expand_path("../../fixtures/generated-concourse-secrets.yml", __FILE__),
        File.expand_path("../../fixtures/concourse-terraform-outputs.yml", __FILE__),
        File.expand_path("../../fixtures/bosh-terraform-outputs.yml", __FILE__),
        File.expand_path("../../fixtures/vpc-terraform-outputs.yml", __FILE__),
      ].join(' ')
    )
    expect(status).to be_success, "build_manifest.sh exited #{status.exitstatus}, stderr:\n#{error}"

    # Deep freeze the object so that it's safe to use across multiple examples
    # without risk of state leaking.
    deep_freeze(YAML.load(output))
  end

  def deep_freeze(object)
    case object
    when Hash
      object.each { |_k, v| deep_freeze(v) }
    when Array
      object.each { |v| deep_freeze(v) }
    end
    object.freeze
  end
end

RSpec.configuration.include ManifestHelpers
