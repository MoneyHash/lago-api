# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::Balance::IncreaseService, type: :service do
  subject(:create_service) { described_class.new(wallet:, credits_amount:) }

  let(:credits_amount) { BigDecimal("4.5") }
  let(:wallet) do
    create(
      :wallet,
      balance_cents: 1000,
      ongoing_balance_cents: 800,
      credits_balance: 10.0,
      credits_ongoing_balance: 8.0
    )
  end

  before { wallet }

  describe ".call" do
    it "updates wallet balance" do
      expect { create_service.call }
        .to change(wallet.reload, :balance_cents).from(1000).to(1450)
        .and change(wallet, :credits_balance).from(10.0).to(14.5)
    end

    it "refreshes wallet ongoing balance" do
      expect { create_service.call }
        .to change(wallet.reload, :ongoing_balance_cents).from(800).to(1450)
        .and change(wallet, :credits_ongoing_balance).from(8.0).to(14.5)
    end

    it "sends a `wallet.updated` webhook" do
      expect { create_service.call }
        .to have_enqueued_job(SendWebhookJob).with("wallet.updated", Wallet)
    end
  end
end
