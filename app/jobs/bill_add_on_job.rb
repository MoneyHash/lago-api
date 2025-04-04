# frozen_string_literal: true

class BillAddOnJob < ApplicationJob
  queue_as do
    if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
      :billing
    else
      :default
    end
  end

  retry_on Sequenced::SequenceError

  def perform(applied_add_on, timestamp)
    result = Invoices::AddOnService.new(
      applied_add_on:,
      datetime: Time.zone.at(timestamp)
    ).create

    result.raise_if_error!
  end
end
