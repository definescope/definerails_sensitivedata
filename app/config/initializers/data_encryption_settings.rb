Rails.application.configure do

  # 16 chars
  raise unless env_encryption_key = ENV['SENSITIVE_DATA_ENCRYPTION_KEY']

  # 8 chars
  codebase_encryption_key =
    if Rails.env.production?
      'a78683f4'
    else
      '286f6ec0'
    end

  # 24 chars
  config.x.sensitive_data_encryption_key =
    codebase_encryption_key + env_encryption_key

end
