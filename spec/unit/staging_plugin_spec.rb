require 'spec_helper'

describe "StagingPlugin class methods" do

  before do
    StagingPlugin.load_all_manifests
  end

  #TODO have these tests validate correct results
  it "returns correct manifest info" do
    info = StagingPlugin.manifests_info
    puts "Manifest info #{info}"
  end

  it "returns correct runtime info" do
    info = StagingPlugin.runtime_info
    puts "Runtime info #{info}"
  end

  it "returns correct runtime ids" do
    info = StagingPlugin.runtime_ids
    puts "Runtime ids #{info}"
  end

  it "returns correct runtime id" do 
    runtime_id = StagingPlugin.runtime_id "Java","1.6.0"
    runtime_id.should == "java"
  end
end
