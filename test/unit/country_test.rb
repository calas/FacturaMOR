require File.dirname(__FILE__) + '/../test_helper'

class CountryTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :chpass_tokens, :customers, :countries, :invoices, :invoice_lines, :addresses

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
