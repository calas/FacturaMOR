# == Schema Information
#
# Table name: login_tokens
#
#  id          :integer(4)      not null, primary key
#  type        :string(255)
#  token       :string(255)     not null
#  account_id  :integer(4)
#  customer_id :integer(4)
#  created_at  :datetime
#  updated_at  :datetime
#

# == Schema Information
# Schema version: 7
#
# Table name: login_tokens
#
#  id          :integer(11)   not null, primary key
#  type        :string(255)   
#  token       :string(255)   not null
#  account_id  :integer(11)   
#  customer_id :integer(11)   
#  created_at  :datetime      
#  updated_at  :datetime      
#

class LoginTokenForCustomer < LoginToken
end
