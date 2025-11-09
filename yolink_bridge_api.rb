# yolink_bridge_api.rb
#
# Class to handle communicating with the YoLink API.

require 'json'
require 'rest-client'

#----------------------------------------------------------------------------

class YolinkBridge
  class API

    #-------------------------

    def initialize(uaid, secret_key)
      @uaid               = uaid
      @secret_key         = secret_key
      @access_token       = nil
      @home_id            = nil
      @devices            = nil
      @yolink_base_req    = 'https://api.yosmart.com/open/yolink'
      @yolink_api_base    = 'v2/api'
    end

    #-------------------------

    # METHOD: send_request
    #   Send a request to the API and return the result.
    #   This is not YoLink specific.

    def send_request(access_token, url, headers=nil, post_data=nil, put_data=nil)
      headers = {} if headers.nil?
      headers[:Authorization] = "Bearer #{access_token}" unless access_token.nil?

      $logger.debug "send_request: url             = #{url      }"
      $logger.debug "send_request: headers         = #{headers  }"
      $logger.debug "send_request: post_data       = #{post_data}" unless post_data.nil?
      $logger.debug "send_request: put_data        = #{put_data }" unless  put_data.nil?

      begin
        if !post_data.nil?
          method = :post
          data   = post_data
        elsif !put_data.nil?
          method = :put
          data   = put_data
        else
          method = :get
          data   = nil
        end

        $logger.debug "send_request: method          = #{method  }"

        response = RestClient::Request.execute(
          method:     method,
          url:        url,
          payload:    data,
          headers:    headers,
          verify_ssl: false
        )

        $logger.debug "send_request: response        = #{response}"

        body = response.body

        $logger.debug "send_request: parsed_response = #{body}"

      rescue RestClient::ExceptionWithResponse => e
        $logger.error "#send_request: Unable to access: #{url} (#{e.response})"
        body = nil
      end

      body
    end

    #-------------------------

    # METHOD: yolink_request
    #   Send a request to the YoLink API and return the result.

    def yolink_request(req, post_data=nil)
      # Get the access token unless we're in the request to get the access token.
      get_access_token unless req == 'token'

      url      = "#{@yolink_base_req}/#{req}"
      headers  = { Content_type: 'application/json', Accept: 'application/json' }

      unless post_data.nil?
        $logger.debug "yolink_request: post_data #{post_data.inspect}"
      end

      # Retry the request in case it fails (it happens sometimes in practice).
      retries = 1
      delay   = 10

      parsed_body = nil
      retries.downto(0).each do |r|
        body = send_request(@access_token, url, headers, post_data.to_json)

        $logger.debug "yolink_request: body: #{body}"

        if body.nil?
          $logger.fatal "Unable to run query: #{url}"
          exit 1
        end

        parsed_body = JSON.parse(body, {symbolize_names: true})

        msg = nil
        if parsed_body.has_key?(:code)
          case parsed_body[:code]
          when '000000' then msg = nil
          when '000101' then msg = "Can't connect to the Hub"
          when '000102' then msg = "Hub can't respond to this command"
          when '000103' then msg = "Token is not valid"
          when '000201' then msg = "Can't connect to the Device"
          when '000202' then msg = "Device can't respond to this command"
          when '000203' then msg = "Can't connect to the Device"
          when '010000' then msg = "Connection not available,try again"
          when '010101' then msg = "Header Error! Customer ID Error"
          when '010201' then msg = "Body Error! Time can not be null"
          when '020102' then msg = "Device mask error"
          when '020201' then msg = "No device searched"
          when '030101' then msg = "No Data found"
          else               msg = "Unknown Error"
          end
        end

        if msg.nil?
          break
        else
          if r.zero?
            $logger.error "Unable to retrieve data (#{parsed_body[:code]}: #{msg})"
            return nil
          else
            $logger.info "yolink_request: Retrying request"
            sleep(delay) 
            # Get a fresh access token in case there was a problem with the
            # old one.  If we're in the process of getting the access token,
            # then we'll just let it try again with the retry.
            get_access_token(true) unless req == 'token'
          end
        end
      end

      if parsed_body.has_key?(:desc) && parsed_body[:desc] != 'Success'
        $logger.error "Request unsuccessful (#{parsed_body[:desc]})"
        return nil
      end

      if parsed_body.nil? || parsed_body.empty?
        $logger.error 'yolink_request: No data returned'
        return nil
      end

      parsed_body
    end

    #-------------------------

    # METHOD: get_access_token
    #   Get an access token for future API and MQTT connections.

    def get_access_token(force=false)
      if !@uaid.nil? && (force || @access_token.nil?)
        req   = 'token'
        login = {
                  grant_type:    'client_credentials',
                  client_id:     @uaid,
                  client_secret: @secret_key
                }

        client_credentials = yolink_request(req, login)
        $logger.debug "client_credentials = #{client_credentials.inspect}"

        @access_token = client_credentials[:access_token]
        $logger.debug "access_token = #{@access_token.inspect}"
      end

      @access_token
    end

    #-------------------------

    # METHOD: get_home_id
    #   Get the home ID for the account.

    def get_home_id
      if @home_id.nil?
        request_data = {
          method: 'Home.getGeneralInfo',
          time:   Time.now.to_i
        }
        body = yolink_request(@yolink_api_base, request_data)
        $logger.debug "GeneralInfo = #{body.inspect}"
        unless body.nil?
          @home_id = body[:data][:id]
          $logger.debug "home_id = #{@home_id}"
        end
      end

      @home_id
    end

    #-------------------------

    # METHOD: get_device_list
    #   Get the list of devices for the account.

    def get_device_list
      if @devices.nil?
        request_data = {
          method: 'Home.getDeviceList',
          time:   Time.now.to_i
        }
        body = yolink_request(@yolink_api_base, request_data)

        @devices = body[:data][:devices] unless body.nil?
      end

      @devices
    end

    #-------------------------

    # METHOD: get_device_list
    #   Get the list of devices for the account in a printable form.

    def get_device_list_printable
      s = ''
      get_device_list&.sort_by { |device| device[:type] }.each do |device|
        s += "#{device.inspect}\n"
      end

      s
    end

    #-------------------------

  end
end

#----------------------------------------------------------------------------
