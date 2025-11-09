#----------------------------------------------------------------------------

require 'json'

#----------------------------------------------------------------------------

# Refresh the device list when the script is loaded.  This will ensure we
# have the current state of the device.
#
# It would be fine if this were done at startup.  But, the on_start trigger
# doesn't seem to work as expected.  So, we'll use on_load for this.

rule 'Refresh device status upon startup' do
  on_load
  run { Yolink_Request.command({ method: 'Home.getDeviceList' }.to_json) }
end

#----------------------------------------------------------------------------

# Any time we get a new device list (like when at startup or when this script
# is loaded), also get the state of each device.

rule 'YoLink device list changed' do
  changed Yolink_Devices
  run {
    if Yolink_Devices.state?
      # Parse the device list and retrieve the state for each listed device.
      devices = JSON.parse(Yolink_Devices.state, {symbolize_names: true})
      devices&.each do |device|
        request = { method: 'getState', targetDevice: device[:deviceId] }
        Yolink_Request.command(request.to_json)
      end
    end
  }
end

#----------------------------------------------------------------------------

# Send E-mail if device is offline or a battery is low.

rule 'Report if devices have issues' do
  every :day, at: '5am'
  run {
    mail_body = ''
    gYolinkOnline.members.each do |item|
      if item.state? && item.state.off?
        mail_body += "#{item.name.gsub(/_/, ' ')} is not online\n"
      end
    end

    unless mail_body.empty?
      mail_to      = 'root' # Put your E-mail address here
      mail_subject = 'YoLink devices offline'
      things['mail:smtp:localhost'].send_mail(mail_to, mail_subject, mail_body)
    end

    mail_body = ''
    gYolinkBattery.members.each do |item|
      if item.state? && item.state.to_i <= 25
        level = case item.state
                when  0 then 'dead'
                when 25 then 'very low'
                end
        mail_body += "#{item.name.gsub(/_/, ' ')} is #{level}\n"
      end
    end

    unless mail_body.empty?
      mail_to      = 'root' # Put your E-mail address here
      mail_subject = 'YoLink battery low'
      things['mail:smtp:localhost'].send_mail(mail_to, mail_subject, mail_body)
    end
  }
end

#----------------------------------------------------------------------------

# Send E-mail if there is an alert for a device.

rule 'Report alert' do
  changed gYolinkAlert.members, to: 'alert'
  run { |event|
    mail_to      = 'root' # Put your E-mail address here
    mail_subject = 'YoLink alert'
    mail_body    = "Alert: #{event.item.name.gsub(/_/, ' ')}"
    things['mail:smtp:localhost'].send_mail(mail_to, mail_subject, mail_body)
  }
end

#----------------------------------------------------------------------------

# The most common thing to do is change the state via the item connected
# to the device's state channel.

rule 'Turn on dimmer; Simple state change example' do
  every :day, at: '6pm' # Or, whatever you need to trigger the rule
  run { Example_Dimmer.command(ON) }
end

# If you make a device/channel and item for brightness, then you can do
# something like this.

rule 'Set dimmer to 75%; parameter specific item example' do
  every :day, at: '7pm' # Or, whatever you need to trigger the rule
  run { Example_Dimmer_Brightness.command(75) }
end

# If you make a device/channel and item for a device request, then you can
# do something like this.

rule 'Turn on dimmer and set it to 50%; device specific request example' do
  every :day, at: '8pm' # Or, whatever you need to trigger the rule
  run {
    request = { method: 'setState', params: { brightness: 50 } }
    Example_Dimmer_Request.command(request.to_json)
  }
end

# If you need to change a device parameter other than state, you can use
# a general request if you haven't created anything special for
# the device and parameter.  You need to put your device's DEVICE-ID in
# the request since it is being processed as a general request.

rule 'Set dimmer to 25%; general request example' do
  every :day, at: '9pm' # Or, whatever you need to trigger the rule
  run {
    request = {
                 method:       'setState',
                 targetDevice: 'DEVICE-ID',
                 params:       { brightness: 25 }
              }
    Yolink_Request.command(request.to_json)
  }
end

#----------------------------------------------------------------------------
