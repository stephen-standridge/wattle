require 'spec_helper'

describe Grouping do

  let(:error) { capture_error {raise RuntimeError.new "test message"} }

  let(:message) {error.message}
  let(:error_class) {error.class.to_s}
  let(:backtrace) { error.backtrace }
  let(:app_env) { 'production' }
  let(:metadata) { { app_env: app_env, language: :ruby } }

  let(:wat) {Wat.new_from_exception(error, metadata) }

  describe "#app_user_stats" do
    subject {grouping.app_user_stats()}
    context "with no app_user info" do
      let(:grouping) {groupings(:grouping1)}
      it {should == {nil => 5}}
    end

    context "with some interesting app_user info" do
      let(:grouping) {groupings(:grouping4)}
      it {should == {nil => 2, "2" => 2, "1" => 1}}
    end
  end

  describe "#app_user_count" do
    subject {grouping.app_user_count()}
    context "with no app_user info" do
      let(:grouping) {groupings(:grouping1)}
      it {should == 0}
    end

    context "with some interesting app_user info" do
      let(:grouping) {groupings(:grouping4)}
      it {should == 2}
    end
  end


  describe "#filtered" do
    let(:filter_params) {{}}
    let(:scope) {Grouping.all}
    subject {scope.filtered(filter_params)}
    it {should have(Grouping.open.count).items}

    context "with an app_name" do
      let(:filter_params) {{app_name: "app1"}}
      it {should have(Grouping.open.app_name(:app1).count).items}
    end

    context "with an app_env" do
      let(:filter_params) {{app_env: "demo"}}
      it {should have(Grouping.open.app_env(:demo).count).items}
    end

    context "with an app_name and an app_env" do
      let(:filter_params) {{app_name: "app2", app_env: "production"}}
      it {should have(Grouping.open.app_name(:app2).app_env("production").count).items}
    end

    context "with a state" do
      let(:filter_params) {{state: :acknowledged}}
      it {should have(1).item}
    end
  end

  describe "#get_or_create_from_wat!" do
    subject {Grouping.get_or_create_from_wat!(wat)}
    it "creates" do
      expect {subject}.to change {Grouping.count}.by 1
    end

    context "with different environments" do
      before do
        Wat.create_from_exception!(error, metadata)
        Wat.create_from_exception!(error, metadata)
        Wat.create_from_exception!(error, {app_env: 'staging'})
      end

      it "groups by app_env" do
        subject.app_envs.should =~ ['production', 'staging']
      end
    end
    context "with a javascript wat" do
      let(:wat) { Wat.create_from_exception!(nil, {language: "javascript"}) {raise RuntimeError.new 'hi'} }
      its(:message) { should == 'hi' }
    end
  end

  describe "#open?" do
    subject {grouping}

    context "with an active wat" do
      let(:grouping) {groupings(:grouping1)}
      it {should be_open}
    end
    context "with an acknowledged wat" do
      let(:grouping) {groupings(:acknowledged)}
      it {should be_open}
    end
    context "with a resolved wat" do
      let(:grouping) {groupings(:resolved)}
      it {should_not be_open}
    end
  end

  describe "#wat_order" do
    subject {Grouping.wat_order}

    it "should be sorted in-order" do
     subject.to_a.should == Grouping.all.sort {|x, y| x.wats.last.id <=> y.wats.last.id}
    end

    context "#reverse" do
      subject {Grouping.wat_order.reverse}
      it "should be sorted in-order" do
        subject.to_a.should == Grouping.all.sort {|x, y| y.wats.last.id <=> x.wats.last.id}
      end
    end
  end
end
