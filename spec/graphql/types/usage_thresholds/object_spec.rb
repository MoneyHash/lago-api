# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::UsageThresholds::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:threshold_display_name).of_type("String")
    expect(subject).to have_field(:recurring).of_type("Boolean!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
