require 'spec_helper'

describe GroupingNotifier do
  let(:grouping_notifier) {GroupingNotifier.new(grouping)}
  let(:grouping) {groupings(:grouping1)}

  describe "#perform" do
    before { stub(grouping_notifier).needs_notifying? {true} }
    subject { grouping_notifier.perform }

    context "send_email_now? is true" do
      before { stub(grouping_notifier).send_email_now? {true} }
      it "should send_email" do
        stub.proxy(grouping_notifier).send_email
        stub.proxy(grouping_notifier).send_email_later
        subject
        expect(grouping_notifier).to have_received(:send_email)
        expect(grouping_notifier).to_not have_received(:send_email_later)
      end
    end
    context "send_email is false" do
      before {stub(grouping_notifier).send_email_now? {false}}
      it "should not send_email" do
        stub.proxy(grouping_notifier).send_email
        stub.proxy(grouping_notifier).send_email_later
        subject
        expect(grouping_notifier).to_not have_received(:send_email)
        expect(grouping_notifier).to have_received(:send_email_later)
      end

    end
  end

  describe "#needs_notifying?" do
    subject {grouping_notifier}
    context "with a blank last_emailed_at" do
      before { grouping.update_column :last_emailed_at, nil }
      context "when the grouping is resolved" do
        let(:grouping) {groupings(:resolved)}
        it {should_not be_needs_notifying}
      end
      context "when the grouping is acknowledged" do
        let(:grouping) {groupings(:acknowledged)}
        it {should_not be_needs_notifying}
      end
      context "when the grouping is active" do
        let(:grouping) {groupings(:grouping1)}
        it {should be_needs_notifying}

        context "with a js grouping" do
          before { stub(grouping).is_javascript? { true } }

          context "with an average of 1000 wats per hour in the last 24 hours" do
            before { stub(grouping_notifier).js_wats_per_hour_in_previous_day { 1000 } }

            context "with 2000 wats in the last hour" do
              before { stub(grouping_notifier).js_wats_in_previous_hour { 2000 } }

              it {should be_needs_notifying}
            end
            context "with 1000 wats in the last hour" do
              before { stub(grouping_notifier).js_wats_in_previous_hour { 1000 } }

              it {should_not be_needs_notifying}
            end
          end
        end
      end
    end
  end

  describe "#send_email_now?" do
    before { stub(grouping_notifier).needs_notifying? {true} }
    subject {grouping_notifier.send_email_now?}
    context "when the grouping was never notified" do
      before { grouping.update_column(:last_emailed_at, nil)}
      it {should be_true}
    end
    context "when the grouping was notified recently" do
      before { grouping.update_column(:last_emailed_at, 1.minute.ago)}
      it {should be_false}
    end
    context "when the grouping was not notified recently" do
      before { grouping.update_column(:last_emailed_at, 1.day.ago)}
      it {should be_true}
      context "with an acknowledged grouping" do
        let(:grouping) {groupings(:acknowledged)}

        it {should be_false}
      end
    end
  end
end