

module DefineRails
  module SensitiveData
    module Models

      module SensitiveDataObject

        module ActiveRecord
          extend ActiveSupport::Concern

          included do
            base.send :extend, ::AttrEncrypted

            class << self; before_save :set_encryption_key end
          end


      #     def set_encryption_key
      #       if self.has_attribute? :encryption_key
      #         # 8 chars
      #         self.encryption_key =
      #           SecureRandom.hex(4) unless self.encryption_key.present?
      #       end
      #     end


      #     def sensitive_data_encryption_key
      #       set_encryption_key
      #       the_key =
      #         self.encryption_key +
      #         Rails.configuration.x.sensitive_data_encryption_key
      #     end


      #     def self.add_encrypted_attribute(attribute_name, opts = {})
      #       unless self.respond_to? attribute_name
      #         self.send :attr_encryptor, attribute_name, key: :sensitive_data_encryption_key,
      #                                                    marshal: true
      #       end
      #     end

      #     def self.add_sensitive_attribute_accessors(attribute_name)

      #       unless self.respond_to? :sensitive_data
      #         self.send :attr_encryptor, :sensitive_data, key: :sensitive_data_encryption_key,
      #                                                     marshal: true
      #       end

      #       self.send(:define_method, attribute_name) do
      #         self.sensitive_data = {} if self.sensitive_data.nil?

      #         self.sensitive_data[attribute_name.to_s]
      #       end

      #       self.send(:define_method, "#{ attribute_name }=") do |the_value|
      #         self.sensitive_data = {} if self.sensitive_data.nil?

      #         self.sensitive_data[attribute_name.to_s] = the_value
      #         self.sensitive_data = self.sensitive_data
      #       end

        end


        module Mongoid
          extend ActiveSupport::Concern

          included do |base|
            base.send :extend, ::AttrEncrypted

            class << self; attr_accessor :is_encryptable end
          end

          def set_encryption_key
            if self.class.is_encryptable?
              # 8 chars
              self.encryption_key =
                SecureRandom.hex(4) unless self.encryption_key.present?
            end
          end

          def sensitive_data_encryption_key
            set_encryption_key
            the_key =
              self.encryption_key +
              Rails.configuration.x.sensitive_data_encryption_key
          end

          module ClassMethods

            def enable_data_encryption
              @is_encryptable = true

              self.send :before_save, :set_encryption_key

              self.send :field, :encryption_key, type: String
            end

            def is_encryptable?
              @is_encryptable
            end

            def add_encrypted_attribute(attribute_name, opts = {})
              db_attribute_name = attribute_name
              attribute_name = opts[:as] || attribute_name

              unless self.respond_to? db_attribute_name
                self.send :field, "encrypted_#{db_attribute_name}", as: "encrypted_#{attribute_name}",
                                                               type: String
                self.send :field, "encrypted_#{db_attribute_name}_iv", as: "encrypted_#{attribute_name}_iv",
                                                                  type: String

                self.send :attr_encryptor, attribute_name, key: :sensitive_data_encryption_key,
                                                      marshal: true,
                                                      encode: true
              end
            end

            def add_sensitive_attribute_accessors(attribute_name)

              unless self.respond_to? :sensitive_data
                self.send :field, :encrypted_snstv_dt, as: :encrypted_sensitive_data,
                                                  type: String
                self.send :field, :encrypted_snstv_dt_iv, as: :encrypted_sensitive_data_iv,
                                                     type: String

                self.send :attr_encryptor, :sensitive_data, key: :sensitive_data_encryption_key,
                                                       marshal: true,
                                                       encode: true
              end

              self.send(:define_method, attribute_name) do
                sensitive_data = {} if sensitive_data.nil?

                sensitive_data[attribute_name.to_s]
              end

              self.send(:define_method, "#{ attribute_name }=") do |the_value|
                sensitive_data = {} if sensitive_data.nil?

                sensitive_data[attribute_name.to_s] = the_value
                sensitive_data = sensitive_data
              end

            end

          end

        end

      end

    end
  end
end
