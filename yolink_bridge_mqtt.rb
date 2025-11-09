# yolink_bridge_mqtt.rb
#
# Class to handle operating an MQTT client.  This can be used for either
# the local MQTT client or the YoLink MQTT client.

require 'paho-mqtt'
require_relative 'yolink_bridge_api'

#----------------------------------------------------------------------------

class YolinkBridge
  class MQTT
    attr_reader :client

    #-------------------------

    # On mqtt clients:
    # - blocking        set to true to allow us to call the loop_* methods and
    #                   capture exceptions.
    # - persistent      set to true to no close connection when no traffic
    #                   coming through.
    # - reconnect_limit set to 0 to not try to reconnect.  We will do that
    #                   ourself with our own backoff mechanism for reconnecting.
    #
    # Note that there isn't a static username/password for the YoLink API.  You
    # have to use the web API to get an access token to use for the username.

    def initialize(type, host, port, client_id, keep_alive)
      @type = type  # :local or :yolink (for debugging messages)
      @connected = false
      @client = PahoMqtt::Client.new(host:            host,
                                     port:            port,
                                     client_id:       client_id,
                                     keep_alive:      keep_alive,
                                     reconnect_limit: 0,
                                     persistent:      true,
                                     blocking:        true)
    end

    #-------------------------

    # METHOD: set_credentials
    #   Set the credentials we need to connect to the MQTT server.

    def set_credentials(username=nil, password=nil)
      @client.username = username
      @client.password = password
    end

    #-------------------------

    # METHOD: connected?
    #   Return whether we are connected to the MQTT server.

    def connected?
      @connected
    end

    #-------------------------

    # METHOD: connect_mqtt_client
    #   Connect to an MQTT client and subscribe to the specified topics.
    #   The status of whether we successfully connected is returned.

    def connect_mqtt_client(subscriptions)
      return true if connected?

      begin
        $logger.debug "#{@type} client.connect"
        @client.connect
        $logger.debug "#{@type} client.connect finished"

        # Subscribe to the specified topics.
        subscriptions.each do |topic|
          @client.subscribe([topic, 0]) # The array defines topic and QoS
          $logger.info "Subscribed to #{@type} topic: #{topic}"
        end

        @connected = true
      rescue => e
        $logger.error "#{@type} client connect failure (#{e.inspect})"
        @connected = false
      end

      connected?
    end

    #-------------------------

    # METHOD: run_mqtt_loop_instance
    #   Since we set blocking mode when we connected, we need to call the client
    #   loop methods to process data for the MQTT connections.  This is necessary
    #   because we want to know when we lose connection for a specific client
    #   (as opposed to getting an exception at an inopportune time).
    #   The status of whether we're still connected is returned.

    def run_mqtt_loop_instance
      @connected = true

      begin
        $logger.debug "before #{@type} client.loop_read"
        @client.loop_read

        $logger.debug "before #{@type} client.loop_write"
        @client.loop_write

        $logger.debug "before #{@type} client.loop_misc"
        @client.loop_misc
      rescue PahoMqtt::WritingException => e
        $logger.debug "#{@type} client failure (#{e.inspect})"
        @connected = false
      end

      $logger.info "#{@type}: connected? #{@client.connected?}, " \
                   "@connected = #{@connected}"
      @connected = false unless @client.connected?

      connected?
    end

    #-------------------------

  end
end

#----------------------------------------------------------------------------
