require "openid"
require "openid/store/filesystem"
require "openid/extensions/ax"
require "openid/extensions/pape"
require "attributes"
require "helpers"

class MojeID
  include MojeIDAttributes

  class DiscoveryFailure < OpenID::DiscoveryFailure; end
  class MojeIDError < OpenID::OpenIDError; end

  attr_accessor :return_to, :realm

  def self.get_openid_store(filestore_path)
    OpenID::Store::Filesystem.new(filestore_path)
  end

  def self.get_consumer(session, store)
    OpenID::Consumer.new(session, store)
  end

  def fetch_request(consumer, identifier="https://mojeid.fred.nic.cz/endpoint/")
    begin
      @auth_request = consumer.begin(identifier)
    rescue OpenID::DiscoveryFailure => f
      raise DiscoveryFailure.new(f.message, f.http_response)
    end
    @ax_request = OpenID::AX::FetchRequest.new
    # pape_request = OpenID::PAPE::Request.new(OpenID::PAPE::AUTH_PHISHING_RESISTANT)
    # @auth_request.add_extension(pape_request)
    @auth_request
  end

  def fetch_response(consumer, params, request, current_url)
    @auth_response = consumer.complete(params.reject { |k, v| request.path_parameters[k] }, current_url)
    if @auth_response.status == OpenID::Consumer::SUCCESS
      @ax_response = OpenID::AX::FetchResponse.from_success_response(@auth_response)
    end
    @auth_response
  end

  # # Add attributes you would like to read about user, to request.
  # # You can pass attribute as array and change options like ns_alias or require.
  # # * example: @moje_id.add_attributes(['http://axschema.org/namePerson', nil, false])
  # # * or simple : @moje_id.add_attributes('http://axschema.org/namePerson')
  # def add_attributes(attributes=[])
  #   attributes.each { |attribute|
  #     attribute.is_a?(Array) ? add_attribute(attribute[0], :ns_alias => attribute[1], :required => attribute[2]) : add_attribute(attribute)
  #   }
  # end

  def add_attribute(attribute, opts={})
    opts[:required] ||= false
    if MojeID.is_attribute_available?(attribute)
      @ax_request.add(OpenID::AX::AttrInfo.new(attribute, opts))
    end
  end

  def pack_attributes_into_request
    @auth_request.add_extension(@ax_request)
  end

  # returns the url you have to redirect after you compose your request
  def redirect_url(immediate=false)
    @auth_request.redirect_url(realm, return_to, immediate)
  end

  private

  # Check if the attribute is available. You can find full list of attributes in lib/attributes.rb
  def self.is_attribute_available?(attribute)
    MojeIDAttributes::AVAILABLE_ATTRIBUTES.include?(attribute) ? true : raise("'#{attribute}' is not available")
  end

end
