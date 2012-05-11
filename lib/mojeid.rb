require "openid"
require "openid/store/filesystem"
require "openid/extensions/ax"
require "openid/extensions/pape"
require "attributes"
require "helpers"

class MojeID
  include MojeIDAttributes

  MOJEID_ENDPOINT = "http://mojeid.cz/endpoint/"
  MOJEID_ENDPOINT_TEST = "https://mojeid.fred.nic.cz/endpoint/"

  @test = false

  def initialize(options={test: false})
    @test = options[:test]
    OpenID::fetcher.ca_file = "#{File.dirname(__FILE__)}/cert/cznic-cacert-test.pem" if @test
  end

  class DiscoveryFailure < OpenID::DiscoveryFailure; end

  attr_accessor :return_to, :realm, :auth_request, :auth_response, :ax_request, :ax_response, :xrds_result

  def self.get_openid_store(filestore_path)
    OpenID::Store::Filesystem.new(filestore_path)
  end

  def self.get_consumer(session, store)
    OpenID::Consumer.new(session, store)
  end

  def fetch_request(consumer)
    identifier = @test ? MOJEID_ENDPOINT_TEST : MOJEID_ENDPOINT
    process_discovery(consumer, identifier)
    @ax_request = OpenID::AX::FetchRequest.new
    pape_request = OpenID::PAPE::Request.new([OpenID::PAPE::AUTH_PHISHING_RESISTANT])
    @auth_request.add_extension(pape_request)
  end

  def fetch_response(consumer, params, request, current_url)
    process_response_by_type(:get, consumer, params, request, current_url)
    @auth_response
  end

  def store_request(consumer)
    identifier = @test ? MOJEID_ENDPOINT_TEST : MOJEID_ENDPOINT
    process_discovery(consumer, identifier)
    @ax_request = OpenID::AX::StoreRequest.new
  end

  def store_response(consumer, params, request, current_url)
    process_response_by_type(:put, consumer, params, request, current_url)
    @auth_response
  end

  # Add attributes you would like to read about user, to request.
  # You can pass attribute as array and change options like ns_alias or require.
  # * example: @moje_id.add_attributes(['http://axschema.org/namePerson', nil, false])
  # * or simple : @moje_id.add_attributes('http://axschema.org/namePerson')
  def add_attributes(attributes=[])
    attributes.each do |attribute|
      attribute.is_a?(Array) ? add_attribute(attribute[0], attribute[1], attribute[2]) : add_attribute(attribute)
    end
    pack_attributes_into_request
  end

  # Add attributes and they values which you would like to update user profile, to the request.
  # Accepts hash like { 'http://axschema.org/namePerson' => 'my new great name' }.
  def update_attributes(data={})
    data.each { |attribute, value| set_attribute(attribute, value) }
    pack_attributes_into_request
  end

  # returns the url you have to redirect after you compose your request
  def redirect_url(immediate=false)
    @auth_request.redirect_url(realm, return_to, immediate)
  end

  def response_status
    case @auth_response.status
    when OpenID::Consumer::FAILURE then return :failure
    when OpenID::Consumer::SUCCESS then return :success
    when OpenID::Consumer::SETUP_NEEDED then return :setup_needed
    when OpenID::Consumer::CANCEL then return :cancel
    else return :unknown
    end
  end

  # Return data parsed to a Hash.
  def data
    @ax_response.data rescue {}
  end

  private

  def process_discovery(consumer, identifier)
    begin
      @auth_request = consumer.begin(identifier)
    rescue OpenID::DiscoveryFailure => f
      raise DiscoveryFailure.new(f.message, f.http_response)
    end
    @xrds_result = OpenID::Yadis::DiscoveryResult.new(@return_to)
  end

  def process_response_by_type(type, consumer, params, request, current_url)
    @auth_response = consumer.complete(params.reject { |k, v| request.path_parameters.key?(k.to_sym) }, current_url)
    if @auth_response.status == OpenID::Consumer::SUCCESS
      if type == :get
        @ax_response = OpenID::AX::FetchResponse.from_success_response(@auth_response)
      elsif type == :put
        @ax_response = OpenID::AX::StoreResponse.from_success_response(@auth_response)
      end
    end
  end

  # Check if the attribute is available. You can find full list of attributes in lib/attributes.rb
  def self.is_attribute_available?(attribute)
    MojeIDAttributes::AVAILABLE_ATTRIBUTES.include?(attribute) ? true : raise("'#{attribute}' is not available")
  end

  def add_attribute(attribute, ns_alias=nil, required=false)
    if MojeID.is_attribute_available?(attribute)
      @ax_request.add(OpenID::AX::AttrInfo.new(attribute, ns_alias, required))
    end
  end

  # Pack attributes and theirs values to request when you would like to store attribute.
  def set_attribute(attribute, value)
    if is_attribute_available?(attribute)
      fetch_request.set_values(attribute, value)
    end
  end

  def pack_attributes_into_request
    @auth_request.add_extension(@ax_request)
  end

end
