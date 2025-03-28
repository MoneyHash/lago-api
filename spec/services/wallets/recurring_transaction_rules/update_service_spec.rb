# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::RecurringTransactionRules::UpdateService do
  subject(:update_service) { described_class.new(wallet:, params:) }

  let(:wallet) { create(:wallet) }
  let(:recurring_transaction_rule) { create(:recurring_transaction_rule, wallet:) }
  let(:params) do
    [
      {
        lago_id: recurring_transaction_rule.id,
        trigger: "interval",
        interval: "weekly",
        paid_credits: "105",
        granted_credits: "105",
        started_at: "2024-05-30T12:48:26Z",
        transaction_metadata:
      }
    ]
  end
  let(:transaction_metadata) { [] }

  describe "#call" do
    before { recurring_transaction_rule }

    it "updates an existing active recurring transaction rule" do
      result = update_service.call

      rule = result.wallet.reload.recurring_transaction_rules.active.first

      aggregate_failures do
        expect(result.wallet.reload.recurring_transaction_rules.count).to eq(1)
        expect(rule).to have_attributes(
          granted_credits: 105.0,
          id: recurring_transaction_rule.id,
          interval: "weekly",
          method: "fixed",
          paid_credits: 105.0,
          started_at: Time.parse("2024-05-30T12:48:26Z"),
          threshold_credits: 0.0,
          trigger: "interval"
        )
      end
    end

    context "when updating an inactive rule" do
      let(:params) do
        [
          {
            lago_id: recurring_transaction_rule.id,
            trigger: "interval",
            interval: "weekly",
            paid_credits: "105",
            granted_credits: "105"
          }
        ]
      end

      it "does not update inactive rules and creates a new one" do
        recurring_transaction_rule.mark_as_terminated!
        result = update_service.call
        active_rule = result.wallet.reload.recurring_transaction_rules.active.first
        expect(result.wallet.reload.recurring_transaction_rules.count).to eq(2)
        expect(result.wallet.reload.recurring_transaction_rules.active.count).to eq(1)
        expect(active_rule).to have_attributes(
          granted_credits: 105,
          id: active_rule.id,
          interval: "weekly",
          method: "fixed",
          paid_credits: 105,
          trigger: "interval"
        )
      end
    end

    context "with added rule without id" do
      let(:params) do
        [
          {
            granted_credits: "105",
            interval: "weekly",
            method: "target",
            paid_credits: "105",
            target_ongoing_balance: "300",
            trigger: "interval"
          }
        ]
      end

      it "creates new recurring transaction rule and terminates existing" do
        result = update_service.call

        rule = result.wallet.reload.recurring_transaction_rules.active.first

        aggregate_failures do
          expect(result.wallet.reload.recurring_transaction_rules.active.count).to eq(1)
          expect(result.wallet.reload.recurring_transaction_rules.terminated.count).to eq(1)
          expect(rule).to have_attributes(
            granted_credits: 105.0,
            interval: "weekly",
            method: "target",
            paid_credits: 105.0,
            target_ongoing_balance: 300.0,
            threshold_credits: 0.0,
            trigger: "interval"
          )
          expect(rule.id).not_to eq(recurring_transaction_rule.id)
        end
      end
    end

    context "when empty array is sent as argument" do
      let(:params) { [] }

      it "terminates all existing recurring transaction rules" do
        result = update_service.call

        expect(result.wallet.reload.recurring_transaction_rules.active.count).to eq(0)
        expect(result.wallet.reload.recurring_transaction_rules.terminated.count).to eq(1)
      end
    end

    context "when sending transaction_metadata" do
      context "when transaction_metadata is valid" do
        let(:transaction_metadata) { [{"key" => "key"}, {"value" => "value"}] }

        it "updates existing recurring transaction rule with new transaction_metadata" do
          result = update_service.call

          rule = result.wallet.reload.recurring_transaction_rules.active.first
          expect(rule.transaction_metadata).to eq(transaction_metadata)
        end
      end
    end
  end
end
