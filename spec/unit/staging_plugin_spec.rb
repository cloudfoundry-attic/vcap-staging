require 'spec_helper'

describe "StagingPlugin class methods" do

  before do
    StagingPlugin.load_all_manifests
  end

  it "returns correct manifest info" do
    info = StagingPlugin.manifests_info
    info['spring'].should == {
      :name=>"spring", :runtimes=>[{:name=>"java", :version=>"1.6", :description=>"Java 6"}],
      :appservers=>[{:name=>"tomcat", :description=>"Tomcat"}], :detection=>[{"*.war"=>true}]}
  end

  it "returns correct runtimes info" do
    info = StagingPlugin.runtimes_info
    info['java'].should == {:description=>"Java 6",:version=>"1.6",:debug_modes=>nil}
  end

  it "returns correct runtimes" do
    info = StagingPlugin.runtimes
    info['java'].should == {'description'=>"Java 6",'version'=>"1.6",'executable'=>'java'}
  end

  it 'returns correct runtime' do
    info = StagingPlugin.runtime 'java'
    info.should == {'name'=> "java", 'description'=>"Java 6",'version'=>"1.6", 'executable'=>'java'}
  end

  it 'returns nil if runtime not found' do
     StagingPlugin.runtime('foo').should == nil
  end

  it "returns correct runtime ids" do
    ids = StagingPlugin.runtime_ids
    ids.sort.should == ["erlangR14B02", "java", "node", "node06", "php", "python2","ruby18", "ruby19"]
  end

  it "return correct framework ids" do
    ids = StagingPlugin.framework_ids
    ids.sort.should == %w[django grails java_web lift node otp_rebar php play rack rails3 sinatra spring standalone wsgi]
  end

  it "filters out disabled runtimes" do
    StagingPlugin.runtimes_info.keys.should_not include('myruntime')
    StagingPlugin.runtime_ids.should_not include('myruntime')
    StagingPlugin.manifests_info['sinatra'][:runtimes].should_not include({
      :name=>"myruntime",:default=>false, :description=>"My Runtime", :version=>"1.0"})
  end

  it 'disallows setting manifest_root to nil' do
    lambda {StagingPlugin.manifest_root=nil }.should raise_error SystemExit
  end
end

