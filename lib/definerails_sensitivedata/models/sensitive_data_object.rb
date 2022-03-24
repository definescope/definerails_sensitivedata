module DefineRails
  module SensitiveData
    module Models

      module SensitiveDataObject

        module ActiveRecord
          extend ActiveSupport::Concern

          included do
            before_save :set_encryption_key
          end

          def set_encryption_key
            if has_attribute? :encryption_key
              _encryption_key = encryption_key
              if _encryption_key.nil? || _encryption_key == ''
                # 8 chars
                self.encryption_key = SecureRandom.hex(4)
              end
            end
          end

          def sensitive_data_encryption_key
            set_encryption_key
            the_key =
              encryption_key +
              ::DefineRails::SensitiveData.application_sensitive_data_encryption_key
          end

          class_methods do

            def add_encrypted_attribute(attribute_name, opts = {})
              treat_nil_as_empty_value =
                opts.delete(:treat_nil_as_empty_value) ? true : false

              empty_value_visible_in_db =
                opts.delete(:empty_value_visible_in_db) ? true : false

              nil_value_visible_in_db =
                (opts.delete(:nil_value_visible_in_db) ? true : false) ||
                (treat_nil_as_empty_value && empty_value_visible_in_db)

              attr_encryptor(
                attribute_name,
                key: :sensitive_data_encryption_key,
                marshal: true,
                allow_empty_value: true,
                **opts
              )

              encryptor_getter_method_name = "__encryptor_#{ attribute_name }"
              encryptor_setter_method_name = "__encryptor_#{ attribute_name }="
              mem_value_attr = "@#{ attribute_name }"

              alias_method encryptor_getter_method_name, attribute_name
              alias_method encryptor_setter_method_name, "#{ attribute_name }="

              encrypted_attribute_name =
                (
                  if opts[:attribute]
                    opts[:attribute]
                  else
                    prefix = opts[:prefix] || 'encrypted_'
                    suffix = opts[:suffix] || ''

                    [ prefix, attribute_name, suffix ].join
                  end
                ).to_sym

              define_method attribute_name do
                unless value = instance_variable_get(mem_value_attr)

                  db_value = send(encrypted_attribute_name)

                  if nil_value_visible_in_db && db_value.nil?
                    return '' if treat_nil_as_empty_value
                    return nil
                  end

                  if empty_value_visible_in_db && db_value == ''
                    return ''
                  end

                  value = send(encryptor_getter_method_name)
                end

                return '' if treat_nil_as_empty_value && value.nil?
                return value
              end

              define_method "#{ attribute_name }=" do |the_value|
                encrypted_attribute_name__set = "#{encrypted_attribute_name}="
                encrypted_attribute_iv_name__set = "#{encrypted_attribute_name}_iv="

                if nil_value_visible_in_db &&
                    the_value.nil? && !treat_nil_as_empty_value
                  send(encrypted_attribute_name__set, nil)
                  send(encrypted_attribute_iv_name__set, nil)
                  instance_variable_set(mem_value_attr, nil)
                  return nil
                end

                if empty_value_visible_in_db &&
                    (
                      the_value == '' ||
                      (treat_nil_as_empty_value && the_value.nil?)
                    )
                  send(encrypted_attribute_name__set, '')
                  send(encrypted_attribute_iv_name__set, '')
                  instance_variable_set(mem_value_attr, '')
                  return ''
                end

                the_value = '' if treat_nil_as_empty_value && the_value.nil?

                send(encryptor_setter_method_name, the_value)
              end
            end

            def add_sensitive_attribute_accessors(attribute_name, opts = {})
              in_attribute = opts.delete(:in) || :sensitive_data

              unless respond_to? in_attribute
                attr_encryptor(
                  in_attribute,
                  key: :sensitive_data_encryption_key,
                  marshal: true,
                  allow_empty_value: true,
                  **opts
                )
              end

              mem_value_attr = "@#{ in_attribute }"

              encrypted_in_attribute_name =
                (
                  if opts[:attribute]
                    opts[:attribute]
                  else
                    prefix = opts[:prefix] || 'encrypted_'
                    suffix = opts[:suffix] || ''

                    [ prefix, in_attribute, suffix ].join
                  end
                ).to_sym

              define_method attribute_name do
                unless the_hash = instance_variable_get(mem_value_attr)
                  db_value = send(encrypted_in_attribute_name)
                  return nil if db_value.nil? || db_value == ''

                  the_hash = send(in_attribute)
                end
                return nil if the_hash.nil? || the_hash == ''

                the_hash.dig(attribute_name)
              end

              define_method "#{ attribute_name }=" do |the_value|
                unless the_hash = instance_variable_get(mem_value_attr)
                  db_value = send(encrypted_in_attribute_name)
                  the_hash =
                    send(in_attribute) unless db_value.nil? || db_value == ''
                end
                the_hash = {} if the_hash.nil? || the_hash == ''

                if the_value.nil?
                  the_hash.delete attribute_name
                else
                  the_hash[attribute_name] = the_value
                end

                send("#{in_attribute}=", the_hash)
              end
            end
          end
        end

        module Mongoid
          extend ActiveSupport::Concern

          included do
            extend ::AttrEncrypted

            before_save :set_encryption_key

            field :encryption_key, type: String
          end

          def set_encryption_key
            _encryption_key = encryption_key
            if _encryption_key.nil? || _encryption_key == ''
              # 8 chars
              self.encryption_key = SecureRandom.hex(4)
            end
          end

          def sensitive_data_encryption_key
            set_encryption_key
            the_key =
              encryption_key +
              ::DefineRails::SensitiveData.application_sensitive_data_encryption_key
          end

          class_methods do

            def add_encrypted_attribute(attribute_name, opts = {})
              treat_nil_as_empty_value =
                opts.delete(:treat_nil_as_empty_value) ? true : false

              empty_value_visible_in_db =
                opts.delete(:empty_value_visible_in_db) ? true : false

              nil_value_visible_in_db =
                (opts.delete(:nil_value_visible_in_db) ? true : false) ||
                (treat_nil_as_empty_value && empty_value_visible_in_db)

              prefix = opts[:prefix] || 'encrypted_'
              suffix = opts[:suffix] || ''

              db_attribute_name = [ prefix, attribute_name, suffix ].join

              attribute_name = opts.delete(:as) || attribute_name

              field_name = opts[:attribute] || [ prefix, attribute_name, suffix ].join

              send(:field, db_attribute_name,
                as: field_name,
                type: String
              )
              send(:field, "#{db_attribute_name}_iv",
                as: "#{field_name}_iv",
                type: String
              )

              send(:attr_encryptor, attribute_name,
                key: :sensitive_data_encryption_key,
                marshal: true,
                encode: true,
                allow_empty_value: true,
                **opts
              )

              encryptor_getter_method_name = "__encryptor_#{ attribute_name }"
              encryptor_setter_method_name = "__encryptor_#{ attribute_name }="
              mem_value_attr = "@#{ attribute_name }"

              alias_method encryptor_getter_method_name, attribute_name
              alias_method encryptor_setter_method_name, "#{ attribute_name }="

              define_method attribute_name do
                unless value = instance_variable_get(mem_value_attr)

                  db_value = send(encrypted_attribute_name)

                  if nil_value_visible_in_db && db_value.nil?
                    return '' if treat_nil_as_empty_value
                    return nil
                  end

                  if empty_value_visible_in_db && db_value == ''
                    return ''
                  end

                  value = send(encryptor_getter_method_name)
                end

                return '' if treat_nil_as_empty_value && value.nil?
                return value
              end

              define_method "#{ attribute_name }=" do |the_value|
                encrypted_attribute_name__set = "#{field_name}="
                encrypted_attribute_iv_name__set = "#{field_name}_iv="

                if nil_value_visible_in_db &&
                    the_value.nil? && !treat_nil_as_empty_value
                  send(encrypted_attribute_name__set, nil)
                  send(encrypted_attribute_iv_name__set, nil)
                  instance_variable_set(mem_value_attr, nil)
                  return nil
                end

                if empty_value_visible_in_db &&
                    (
                      the_value == '' ||
                      (treat_nil_as_empty_value && the_value.nil?)
                    )
                  send(encrypted_attribute_name__set, '')
                  send(encrypted_attribute_iv_name__set, '')
                  instance_variable_set(mem_value_attr, '')
                  return ''
                end

                the_value = '' if treat_nil_as_empty_value && the_value.nil?

                send(encryptor_setter_method_name, the_value)
              end
            end

            def add_sensitive_attribute_accessors(attribute_name, opts = {})
              in_attribute = opts.delete(:in) || :sensitive_data
              in_field_name = opts[:attribute] || opts.delete(:in_db) || [ prefix, in_attribute, suffix ].join

              unless respond_to? in_attribute
                send(:field, in_field_name,
                  type: String
                )
                send(:field, "#{in_field_name}_iv",
                  type: String
                )

                send(:attr_encryptor, in_attribute,
                  key: :sensitive_data_encryption_key,
                  marshal: true,
                  encode: true,
                  allow_empty_value: true,
                  attribute: in_field_name,
                  **opts
                )
              end

              mem_value_attr = "@#{ in_attribute }"

              send(:define_method, attribute_name) do
                unless the_hash = instance_variable_get(mem_value_attr)
                  db_value = send(in_field_name)
                  return nil if db_value.nil? || db_value == ''

                  the_hash = send(in_attribute)
                end
                return nil if the_hash.nil? || the_hash == ''

                the_hash.dig(attribute_name)
              end

              send(:define_method, "#{ attribute_name }=") do |the_value|
                unless the_hash = instance_variable_get(mem_value_attr)
                  db_value = send(in_field_name)
                  the_hash =
                    send(in_attribute) unless db_value.nil? || db_value == ''
                end
                the_hash = {} if the_hash.nil? || the_hash == ''

                if the_value.nil?
                  the_hash.delete attribute_name
                else
                  the_hash[attribute_name] = the_value
                end

                send("#{in_attribute}=", the_hash)
              end
            end
          end
        end
      end
    end
  end
end
