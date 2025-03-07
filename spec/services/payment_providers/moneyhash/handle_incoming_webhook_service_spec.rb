# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Moneyhash::HandleIncomingWebhookService, type: :service do
  let(:webhook_service) { described_class.new(organization_id:, body:) }

  let(:organization) { create(:organization) }
  let(:organization_id) { organization.id }
  let(:moneyhash_provider) { create(:moneyhash_provider, organization:) }

  let(:body) { JSON.parse(intent_processed_event) }

  let(:intent_processed_event) do
    path = Rails.root.join("spec/fixtures/moneyhash/intent.processed.json")
    File.read(path)
  end

  before { moneyhash_provider }

  describe "intent processed event" do
    it "updates the payment status" do
      expect { webhook_service.call }.to change { payment.reload.status }.to("succeeded")
    end
  end
end
