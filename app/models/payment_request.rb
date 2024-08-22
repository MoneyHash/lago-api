# frozen_string_literal: true

class PaymentRequest < ApplicationRecord
  include PaperTrailTraceable

  has_many :applied_invoices, class_name: "PaymentRequest::AppliedInvoice"
  has_many :invoices, through: :applied_invoices
  has_many :payments, as: :payable

  belongs_to :organization
  belongs_to :customer, -> { with_discarded }

  validates :email, presence: true
  validates :amount_cents, presence: true
  validates :amount_currency, presence: true

  PAYMENT_STATUS = %i[pending succeeded failed].freeze

  enum payment_status: PAYMENT_STATUS, _prefix: :payment
end

# == Schema Information
#
# Table name: payment_requests
#
#  id              :uuid             not null, primary key
#  amount_cents    :bigint           default(0), not null
#  amount_currency :string           not null
#  email           :string           not null
#  payment_status  :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  customer_id     :uuid             not null
#  organization_id :uuid             not null
#
# Indexes
#
#  index_payment_requests_on_customer_id      (customer_id)
#  index_payment_requests_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (organization_id => organizations.id)
#
