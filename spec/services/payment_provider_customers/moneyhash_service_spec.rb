# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::MoneyhashService, type: :service do
  subject(:moneyhash_service) { described_class.new(moneyhash_customer) }

  let(:customer) { create(:customer, name: customer_name, organization:) }
  let(:moneyhash_provider) { create(:moneyhash_provider) }
  let(:organization) { moneyhash_provider.organization }
  let(:customer_name) { nil }

  let(:moneyhash_customer) do
    create(:moneyhash_customer, customer:, provider_customer_id: nil)
  end

  describe "#create" do
    context "when provider_customer_id is already present" do
      before {
        moneyhash_customer.update(provider_customer_id: SecureRandom.uuid)
        allow(moneyhash_service).to receive(:create_moneyhash_customer) # rubocop:disable RSpec/SubjectStub
      }

      it "does not call moneyhash API" do
        result = moneyhash_service.create
        expect(result).to be_success
        expect(moneyhash_service).not_to have_received(:create_moneyhash_customer) # rubocop:disable RSpec/SubjectStub
      end
    end

    context "when provider_customer_id is not present" do
      let(:moneyhash_result) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/create_customer.json"))) }

      before do
        allow(moneyhash_service).to receive(:create_moneyhash_customer).and_return(moneyhash_result) # rubocop:disable RSpec/SubjectStub
        allow(moneyhash_service).to receive(:deliver_success_webhook) # rubocop:disable RSpec/SubjectStub
      end

      it "creates the moneyhash customer and sends a success webhook" do
        result = moneyhash_service.create
        expect(result).to be_success
        expect(moneyhash_service).to have_received(:create_moneyhash_customer) # rubocop:disable RSpec/SubjectStub
        expect(moneyhash_customer.reload.provider_customer_id).to eq(moneyhash_result["data"]["id"])
        expect(moneyhash_service).to have_received(:deliver_success_webhook) # rubocop:disable RSpec/SubjectStub
      end
    end

    # describe "#update" do
    #   let(:moneyhash_customer) do
    #     create(:moneyhash_customer, customer:, provider_customer_id:)
    #   end

    #   before { moneyhash_customer }
    # end
  end
end
