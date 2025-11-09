# OpenHAB configuration for yolink_bridge

These files are used to allow OpenHAB to interact with yolink_bridge (and
thus the YoLink MQTT broker).  Each user will have a different setup.
These files just give you a starting point.

---

## Prerequisites

* MQTT broker (Mosquitto or other)
* YoLink devices and YoLink credentials
* jruby (if using JRuby rules)
* OpenHAB
* OpenHAB MQTT Binding add-on
* OpenHAB Map transformation add-on
* OpenHAB JRuby Scripting automation add-on (or whatever rule language you choose)
* OpenHAB "thing" setup for local MQTT broker
* yolink_bridge application

---

## Examples

Note that in the provided example files, anywhere there are a series of Xs,
those values will need to be changed to something appropriate for your setup.

### things

OpenHAB requires "things" to be set up to interface with physical devices.
Each thing may have multiple channels.

Things can be created in .things files or in the user interface.
Use whatever works for you.

#### yolink.things

A thing for each device.  We also create a couple of special things.
One for general information ("home").   And one for raw data exchange
("request"), which we use for sending requests.

Under each thing, we create a channel for the data items we wish to
retrieve.  The `stateTopic` parameter is the local MQTT topic that will
provide the desired value.  A `commandTopic` may be specified to send the
value, when changed by OpenHAB.

Each channel may have some additional parameters that control how OpenHAB
treats the values.

### items

#### yolink.items

OpenHAB uses items to allow rules, and other interfaces, to access the
YoLink values. These can be setup in files or the user interface.

Each item needs to be tied to a thing channel.  Each device value can
then be accessed by name by OpenHAB.

### transform

There are many different ways to transform values so that they make more
sense to display or process in OpenHAB.  These are a couple I use.

#### battery4.map

Transforms YoLink's 0-4 battery level to a 0 to 100 percentage.

#### dBm.rb

Transforms a signal level (in dBm) to a 0 to 100 percentage.

### automation/ruby

#### yolink.rb

This script contains the rules necessary to run during startup and to do
some reporting for anomalous conditions.  OpenHAB handles most of the
interactions with the devices automatically based on the things/items
configurations.

There are several different ways to set YoLink parameters based on which
request method you want to use.  See the dimmer examples to show how to
handle requests in different ways.
