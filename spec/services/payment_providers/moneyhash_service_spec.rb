# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::MoneyhashService, type: :service do
  subject(:moneyhash_service) { described_class.new }

  let(:organization) { create(:organization) }
  let(:code) { "moneyhash_1" }
  let(:name) { "MoneyHash" }
  let(:api_key) { "mh_test_key" }
  let(:flow_id) { "flow_123" }

  describe "#create_or_update" do
    let(:params) do
      {
        organization: organization,
        code: code,
        name: name,
        api_key: api_key,
        flow_id: flow_id
      }
    end

    context "when creating a new provider" do
      it "creates a new moneyhash provider" do
        expect { moneyhash_service.create_or_update(**params) }
          .to change(PaymentProviders::MoneyhashProvider, :count).by(1)

        provider = PaymentProviders::MoneyhashProvider.last
        expect(provider.organization).to eq(organization)
        expect(provider.code).to eq(code)
        expect(provider.name).to eq(name)
        expect(provider.api_key).to eq(api_key)
        expect(provider.flow_id).to eq(flow_id)
      end

      it "returns success result" do
        result = moneyhash_service.create_or_update(**params)

        expect(result).to be_success
        expect(result.moneyhash_provider).to be_present
      end
    end

    context "when updating existing provider" do
      let!(:existing_provider) do
        create(:moneyhash_provider,
          organization: organization,
          code: code,
          name: "Old Name",
          api_key: "old_key",
          flow_id: "old_flow")
      end

      let(:new_params) do
        {
          organization: organization,
          code: code,
          name: "Updated Name",
          api_key: "new_key",
          flow_id: "new_flow"
        }
      end

      it "updates the existing provider" do
        expect { moneyhash_service.create_or_update(**new_params) }
          .not_to change(PaymentProviders::MoneyhashProvider, :count)

        existing_provider.reload
        expect(existing_provider.name).to eq("Updated Name")
        expect(existing_provider.api_key).to eq("new_key")
        expect(existing_provider.flow_id).to eq("new_flow")
      end

      it "returns success result with updated provider" do
        result = moneyhash_service.create_or_update(**new_params)

        expect(result).to be_success
        expect(result.moneyhash_provider).to eq(existing_provider)
      end

      context "when code is changed" do
        let(:customers) { create_list(:customer, 2, organization: organization, payment_provider: existing_provider) }
        let(:new_code) { "new_moneyhash_code" }

        before { customers }

        it "updates payment_provider_code for all associated customers" do
          moneyhash_service.create_or_update(**new_params.merge(code: new_code))

          customers.each do |customer|
            expect(customer.reload.payment_provider_code).to eq(new_code)
          end
        end
      end
    end

    context "when validation fails" do
      let(:invalid_params) do
        {
          organization: organization,
          code: code,
          name: "A" * 300 # Name too long
        }
      end

      it "returns failure result" do
        result = moneyhash_service.create_or_update(**invalid_params)

        expect(result).not_to be_success
        expect(result.error).to be_present
        expect(result.error.messages[:name]).to be_present
      end
    end
  end
end
