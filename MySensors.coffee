module.exports = (env) ->

  V_TEMP             = 0
  V_HUM              = 1
  V_LIGHT            = 2
  V_DIMMER           = 3
  V_PRESSURE         = 4
  V_FORECAST         = 5
  V_RAIN             = 6
  V_RAINRATE         = 7
  V_WIND             = 8
  V_GUST             = 9
  V_DIRECTION        = 10
  V_UV               = 11
  V_WEIGHT           = 12
  V_DISTANCE         = 13
  V_IMPEDANCE        = 14
  V_ARMED            = 15
  V_TRIPPED          = 16
  V_WATT             = 17
  V_KWH              = 18
  V_SCENE_ON         = 19
  V_SCENE_OFF        = 20
  V_HEATER           = 21
  V_HEATER_SW        = 22
  V_LIGHT_LEVEL      = 23
  V_VAR1             = 24
  V_VAR2             = 25
  V_VAR3             = 26
  V_VAR4             = 27
  V_VAR5             = 28
  V_UP               = 29
  V_DOWN             = 30
  V_STOP             = 31
  V_IR_SEND          = 32
  V_IR_RECEIVE       = 33
  V_FLOW             = 34
  V_VOLUME           = 35
  V_LOCK_STATUS      = 36

  ZERO_VALUE         = "0"

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  Board = require('./board')

  Promise.promisifyAll(Board.prototype)

  class MySensors extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      @board = new Board(@framework, @config)

      @board.connect().then( =>
        env.logger.info("Connected to MySensors Gateway.")
      ) 
        
      deviceConfigDef = require("./device-config-schema")

      deviceClasses = [
        MySensorsDHT
        MySensorsBMP
        MySensorsPIR
        MySensorsSwitch
        MySensorsPulseMeter
        MySensorsButton
        MySensorsLight
        MySensorsGas
        MySensorBattery
        MySensorsTemp
        MySensorsDistance
      ]

      for Cl in deviceClasses
        do (Cl) =>
          @framework.deviceManager.registerDeviceClass(Cl.name, {
            configDef: deviceConfigDef[Cl.name]
            createCallback: (config,lastState) => 
             device  =  new Cl(config,lastState, @board)
             return device
            })
      #env.logger.info @framework.deviceManager.devicesConfig.length
       
  class MySensorsDHT extends env.devices.TemperatureSensor

    constructor: (@config,lastState, @board) ->
      @id = config.id
      @name = config.name 
      env.logger.info "MySensorsDHT " , @id , @name 

      @attributes = {}

      @attributes.temperature = {
        description: "the messured temperature"
        type: "number"
        unit: '°C'
      }

      @attributes.humidity = {
          description: "the messured humidity"
          type: "number"
          unit: '%'
      }
     
      @board.on("rfValue", (result) =>
        if result.sender is @config.nodeid
          for sensorid in @config.sensorid
            if result.sensor is sensorid
              env.logger.info "<- MySensorDHT " , result
              if result.type is V_TEMP
                #env.logger.info  "temp" , result.value 
                @_temperatue = parseFloat(result.value)
                @emit "temperature", @_temperatue
              if result.type is V_HUM
                #env.logger.info  "humidity" , result.value
                @_humidity = Math.round(parseFloat(result.value))
                @emit "humidity", @_humidity
      )
      super()

    getTemperature: -> Promise.resolve @_temperatue
    getHumidity: -> Promise.resolve @_humidity

  class MySensorsBMP extends env.devices.TemperatureSensor

    constructor: (@config,lastState, @board) ->
      @id = config.id
      @name = config.name
      env.logger.info "MySensorsBMP " , @id , @name

      @attributes = {}

      @attributes.temperature = {
        description: "the messured temperature"
        type: "number"
        unit: '°C'
      }

      @attributes.pressure = {
          description: "the messured pressure"
          type: "number"
          unit: 'hPa'
      }

      @attributes.forecast = {
          description: "the forecast"
          type: "string"
      }

      @board.on("rfValue", (result) =>
        if result.sender is @config.nodeid
          for sensorid in @config.sensorid
            if result.sensor is sensorid
              env.logger.info "<- MySensorBMP " , result
              if result.type is V_TEMP
                #env.logger.info  "temp" , result.value 
                @_temperatue = parseInt(result.value)
                @emit "temperature", @_temperatue
              if result.type is V_PRESSURE
                #env.logger.info  "pressure" , result.value
                @_pressure = parseInt(result.value)
                @emit "pressure", @_pressure
              if result.type is V_FORECAST
                #env.logger.info  "forecast" , result.value
                @_forecast = result.value
                @emit "forecast", @_forecast

      )
      super()

    getTemperature: -> Promise.resolve @_temperatue
    getPressure: -> Promise.resolve @_pressure
    getForecast: -> Promise.resolve @_forecast

  class MySensorsPulseMeter extends env.devices.Device

    constructor: (@config,lastState, @board) ->
      @id = config.id
      @name = config.name
      @_totalkw = 0
      @_tickcount = 0
      env.logger.info "MySensorsPulseMeter " , @id , @name

      @attributes = {}

      @attributes.watt = {
        description: "the messured Wattage"
        type: "number"
        unit: 'W'
      }

      @attributes.kW = {
        description: "the messured Kilo Wattage"
        type: "number"
        unit: 'kW'
      }

      @attributes.kWh = {
        description: "the messured Kwh"
        type: "number"
        unit: 'kWh'
      }

      calcuatekwh = ( =>
        @_avgkw =  @_totalkw / @_tickcount 
        @_kwh = (@_avgkw * (@_tickcount * 10)) / 3600     
        @_tickcount = 0 
        @_totalkw  = 0
        env.logger.info  "calculatekwh.." , @kwh
        @emit "kWh", @_kwh
      )

      @board.on("rfValue", (result) =>
        if result.sender is @config.nodeid
          for sensorid in @config.sensorid
            if result.sensor is sensorid
              env.logger.info "<- MySensorsPulseMeter" , result
              if result.type is V_WATT
                #env.logger.info  "temp" , result.value 
                @_watt = parseInt(result.value)
                @_kw = @_watt/1000
                @_totalkw += @_kw
                @_tickcount++ # ~per 10 second  
                setTimeout(calcuatekwh, 1800000)
                @emit "kW", @_kw
                @emit "watt", @_watt
      )
      super()

    getWatt: -> Promise.resolve @_watt
    getKW: -> Promise.resolve @_kw
    getKWh: -> Promise.resolve @_kwh

  class MySensorsPIR extends env.devices.PresenceSensor

    constructor: (@config,lastState,@board) ->
      @id = config.id
      @name = config.name
      @_presence = lastState?.presence?.value or false
      env.logger.info "MySensorsPIR " , @id , @name, @_presence

      resetPresence = ( =>
        @_setPresence(no)
      )

      @board.on('rfValue', (result) =>
        if result.sender is @config.nodeid and result.type is V_TRIPPED and result.sensor is @config.sensorid
          env.logger.info "<- MySensorPIR ", result
          unless result.value is ZERO_VALUE
            @_setPresence(yes)
          clearTimeout(@_resetPresenceTimeout)
        @_resetPresenceTimeout = setTimeout(resetPresence, @config.resetTime)
      )
      super()

    getPresence: -> Promise.resolve @_presence

   class MySensorsButton extends env.devices.ContactSensor

    constructor: (@config,lastState,@board) ->
      @id = config.id
      @name = config.name
      @_contact = lastState?.contact?.value or false
      env.logger.info "MySensorsButton" , @id , @name, @_contact

      @board.on('rfValue', (result) =>
        if result.sender is @config.nodeid and result.type is ( V_TRIPPED or V_LIGHT ) and result.sensor is @config.sensorid
          env.logger.info "<- MySensorsButton ", result
          if result.value is ZERO_VALUE
            @_setContact(yes)
          else
            @_setContact(no)
      )
      super()


  class MySensorsSwitch extends env.devices.PowerSwitch

    constructor: (@config,lastState,@board) ->
      @id = config.id
      @name = config.name
      @_state = lastState?.state?.value
      env.logger.info "MySensorsSwitch " , @id , @name, @_state

      @board.on('rfValue', (result) =>
        if result.sender is @config.nodeid and result.type is V_LIGHT and result.sensor is @config.sensorid 
          state = (if parseInt(result.value) is 1 then on else off)
          env.logger.info "<- MySensorSwitch " , result
          @_setState(state)
        )
      super()

    changeStateTo: (state) ->     
      assert state is on or state is off
      if state is true then _state = 1  else _state = 0 
      datas = {}      
      datas = 
      { 
        "destination": @config.nodeid, 
        "sensor": @config.sensorid, 
        "type"  : V_LIGHT,
        "value" : _state,
        "ack"   : 1
      } 
      @board._rfWrite(datas).then ( () =>
         @_setState(state)
      )

  class MySensorBattery extends env.devices.Device

    constructor: (@config,lastState, @board) ->
      @id = config.id
      @name = config.name
      env.logger.info "MySensorBattery" , @id , @name

      @attributes = {}

      for nodeid in @config.nodeid
        do (nodeid) =>
          attr = "battery_" + nodeid
          @attributes[attr] = {
            description: "the measured Battery Stat of Sensor"
            type: "number"
            unit: '%'
          }
          getter = ( =>  Promise.resolve @_batterystat )
          @_createGetter( attr, getter)

      @board.on("rfbattery", (result) =>
         unless result.value is null or undefined
          @_batterystat =  parseInt(result.value)
          @emit "battery_" + result.sender, @_batterystat
      )
      super()


  class MySensorsLight extends env.devices.Device

    constructor: (@config,lastState, @board) ->
      @id = config.id
      @name = config.name
      env.logger.info "MySensorsLight " , @id , @name
      @attributes = {}

      @attributes.light = {
        description: "the messured light"
        type: "number"
        unit: '%'
      }

      @board.on("rfValue", (result) =>
        if result.sender is @config.nodeid
          if result.sensor is  @config.sensorid
            env.logger.info "<- MySensorsLight" , result
            if result.type is V_LIGHT_LEVEL
              @_light = parseInt(result.value)
              @emit "light", @_light
      )
      super()

    getLight: -> Promise.resolve @_light

    
  class MySensorsGas extends env.devices.Device

    constructor: (@config,lastState, @board) ->
      @id = config.id
      @name = config.name
      env.logger.info "MySensorsGas " , @id , @name
      @attributes = {}

      @attributes.gas = {
        description: "the messured gas presence in ppm"
        type: "number"
        unit: 'ppm'
      }

      @board.on("rfValue", (result) =>
        if result.sender is @config.nodeid
          if result.sensor is  @config.sensorid
            env.logger.info "<- MySensorsGas" , result
            if result.type is V_VAR1
              @_gas = parseInt(result.value)
              @emit "gas", @_gas
      )
      super()

    getGas: -> Promise.resolve @_gas
    
  class MySensorsTemp extends env.devices.TemperatureSensor

    constructor: (@config,lastState, @board) ->
      @id = config.id
      @name = config.name 
      env.logger.info "MySensorsTemp " , @id , @name 
      @attributes = {}

      @attributes.temperature = {
        description: "the messured temperature"
        type: "number"
        unit: '°C'
      }

      @board.on("rfValue", (result) =>
          if result.sender is @config.nodeid
            if result.sensor is  @config.sensorid
              env.logger.info "<- MySensorTemp " , result
              if result.type is V_TEMP
                @_temperatue = parseFloat(result.value)
                @emit "temperature", @_temperatue
      )
      super()

    getTemperature: -> Promise.resolve @_temperatue

  class MySensorsDistance extends env.devices.Device

    constructor: (@config,lastState, @board) ->
      @id = config.id
      @name = config.name
      env.logger.info "MySensorsDistance " , @id , @name
      @attributes = {}

      @attributes.Distance = {
        description: "the messured distance in cm"
        type: "number"
        unit: 'cm'
      }

      @board.on("rfValue", (result) =>
        if result.sender is @config.nodeid
          if result.sensor is  @config.sensorid
            env.logger.info "<- MySensorsDistance" , result
            if result.type is V_DISTANCE
              @_Distance = parseInt(result.value)
              @emit "Distance", @_Distance
      )
      super()

    getDistance: -> Promise.resolve @_Distance
  # ###Finally
  # Create a instance of my plugin
  mySensors = new MySensors
  # and return it to the framework.
  return mySensors
