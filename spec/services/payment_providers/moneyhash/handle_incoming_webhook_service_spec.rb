# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Moneyhash::HandleIncomingWebhookService, type: :service do
  let(:webhook_service) { described_class.new(organization_id:, code:, source: :moneyhash, payload: body, signature: nil, event_type: body["type"]) }

  let(:organization) { create(:organization) }
  let(:organization_id) { organization.id }
  let(:moneyhash_provider) { create(:moneyhash_provider, organization:) }
  let(:payment_provider_result) { BaseService::Result.new }

  let(:body) { JSON.parse(intent_processed_event).to_h }
  let(:code) { moneyhash_provider.code }

  let(:intent_processed_event) do
    path = Rails.root.join("spec/fixtures/moneyhash/intent.processed.json")
    File.read(path)
  end

  before { moneyhash_provider }

  describe "incoming webhook event" do
    before do
      allow(PaymentProviders::FindService).to receive(:call)
        .with(organization_id:, code: moneyhash_provider.code, payment_provider_type: "moneyhash")
        .and_return(payment_provider_result)
      allow(PaymentProviders::Moneyhash::HandleEventJob).to receive(:perform_later)
    end

    it "triggers Moneyhash::HandleEventJob" do
      webhook_service.call

      expect(PaymentProviders::Moneyhash::HandleEventJob).to have_received(:perform_later)
        .with(organization:, event_json: body)
    end
  end
end
