# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::Void, type: :graphql do
  let(:required_permission) { "invoices:void" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, status: :finalized, customer:, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: VoidInvoiceInput!) {
        voidInvoice(input: $input) {
          id
          status
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:void"

  it "voids the given invoice" do
    freeze_time do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: invoice.id}
        }
      )

      result_data = result["data"]["voidInvoice"]

      aggregate_failures do
        expect(result_data["id"]).to be_present
        expect(result_data["status"]).to eq("voided")
      end
    end
  end
end
