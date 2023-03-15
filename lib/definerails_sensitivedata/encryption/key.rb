module DefineRails
  module SensitiveData
    module Encryption

      class Key < ::ActiveRecord::Encryption::Key

        def initialize(password)
          @password = password
          super(
            ::ActiveRecord::Encryption.key_generator.derive_key_from(password)
          )
        end

        def with_salt(salt)
          self.class.derive_from(@password, salt)
        end

        def self.derive_from(password, salt = nil)
          if salt.nil?
            Key.new(password)
          else
            Key.new("#{password}_#{salt}")
          end
        end

      end

    end
  end
end
