# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Integrations::Netsuite do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:client_id).of_type("String")
    expect(subject).to have_field(:client_secret).of_type("String")
    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:has_mappings_configured).of_type("Boolean")
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:script_endpoint_url).of_type("String!")
    expect(subject).to have_field(:token_id).of_type("String")
    expect(subject).to have_field(:token_secret).of_type("String")

    expect(subject).to have_field(:sync_credit_notes).of_type("Boolean")
    expect(subject).to have_field(:sync_invoices).of_type("Boolean")
    expect(subject).to have_field(:sync_payments).of_type("Boolean")
  end
end
