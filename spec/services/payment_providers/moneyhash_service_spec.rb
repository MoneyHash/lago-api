# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::MoneyhashService, type: :service do
  let(:organization) { create(:organization) }
  let(:moneyhash_provider) { create(:moneyhash_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:moneyhash_customer) { create(:moneyhash_customer, customer:) }

  # Intent
  # handle event - intent.processed <-
  # handle event - intent.time_expired
  describe "#handle_intent_event" do
    let(:intent_processed_event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/intent.processed.json"))) }
    # intent payment & invoice
    let(:payment) { create(:payment, provider_payment_id: intent_processed_event_json.dig("data", "intent_id"), payable: invoice) }
    let(:invoice) { create(:invoice, organization:, customer:) }

    it "handles intent.processed event" do
      intent_processed_event_json["data"]["intent"]["custom_fields"]["lago_payable_type"] = "Invoice"
      intent_processed_event_json["data"]["intent"]["custom_fields"]["lago_payable_id"] = invoice.id

      payment
      result = described_class.new.handle_event(organization:, event_json: intent_processed_event_json)
      payment.reload
      expect(result).to be_success
      expect(payment.status).to eq("succeeded")
      expect(payment.payable.payment_status).to eq("succeeded")
    end
  end

  # Transaction
  # handle event - transaction.purchase.successful <-
  # handle event - transaction.purchase.pending_authentication
  # handle event - transaction.purchase.failed
  describe "#handle_transaction_event" do
    let(:transaction_successful_event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/transaction.purchase.successful.json"))) }
    let(:transaction_failed_event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/transaction.purchase.failed.json"))) }

    # transaction payment & invoice
    let(:payment) { create(:payment, provider_payment_id: transaction_successful_event_json.dig("intent", "id"), payable: invoice) }
    let(:invoice) { create(:invoice, organization:, customer:) }

    it "handles transaction.purchase.successful event" do
      transaction_successful_event_json["intent"]["custom_fields"]["lago_payable_type"] = "Invoice"
      transaction_successful_event_json["intent"]["custom_fields"]["lago_payable_id"] = invoice.id
      transaction_successful_event_json["intent"]["custom_fields"]["lago_customer_id"] = moneyhash_customer.customer_id

      moneyhash_provider
      moneyhash_customer
      payment
      result = described_class.new.handle_event(organization:, event_json: transaction_successful_event_json)
      payment.reload
      expect(result).to be_success
      expect(payment.status).to eq("succeeded")
      expect(payment.payable.payment_status).to eq("succeeded")
    end
  end

  # Card Token
  # handle event - card_token.created <-
  # handle event - card_token.updated <-
  # handle event - card_token.deleted
  describe "#handle_card_event" do
    before do
      moneyhash_provider
      moneyhash_customer
    end

    it "handles card_token.created event" do
      card_token_created_event_json = JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/card_token.created.json")))
      card_token_created_event_json["data"]["card_token"]["custom_fields"]["lago_customer_id"] = moneyhash_customer.customer_id

      result = described_class.new.handle_event(organization:, event_json: card_token_created_event_json)
      expect(result).to be_success
      moneyhash_customer.reload
      expect(moneyhash_customer.payment_method_id).to eq(card_token_created_event_json.dig("data", "card_token", "id"))
    end

    it "handles card_token.updated event" do
      card_token_updated_event_json = JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/card_token.updated.json")))
      card_token_updated_event_json["data"]["card_token"]["custom_fields"]["lago_customer_id"] = moneyhash_customer.customer_id

      result = described_class.new.handle_event(organization:, event_json: card_token_updated_event_json)
      expect(result).to be_success
      moneyhash_customer.reload
      expect(moneyhash_customer.payment_method_id).to eq(card_token_updated_event_json.dig("data", "card_token", "id"))
    end
  end
end
