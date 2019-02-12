# Description:
#   Check for user presence at the space
#
# Commands:
#   hubot setup presence - Add new device to users presence list
#   hubot who's at the space - Get users currently at the space. (PM or Members channel only)
#   hubot enable|disable presence - Turn on or off your presence notifications
uuid = require('uuid/v4')
Unifi = require('ubnt-unifi')
cronJob = require('cron').CronJob

presenceNotificationDelay = 6*60*60*1000
#presenceNotificationDelay = 60*1000

module.exports = (robot) ->
  class Presence
    userWithMAC:(mac) ->
      for user of robot.brain.data.users
        if this.hasMac user, mac
          return user
      return null
    hasMac:(user,mac) ->
      userDevices = this.userDevices user
      if userDevices
        for macK in userDevices
          if macK == mac
            return true
      return false
    userDevices:(user) ->
      userDevices = []
      userData = robot.brain.data.users[user]
      if userData.presence?.devices
        userDevices = userData.presence.devices
      return userDevices
    userToken: (token) ->
      for user of robot.brain.data.users
        if robot.brain.data.users[user].presence?.accessToken == token
          return user
      return null
    usersPresent: () ->
      present = 0
      for user of robot.brain.data.users
        if robot.brain.data.users[user].presence?.atSpace
          present = present + 1
      return present
  robot.presence = new Presence()
  robot.unifi = new Unifi({
    host: process.env.HUBOT_UNIFI_HOST,
    port: process.env.HUBOT_UNIFI_PORT,
    username: process.env.HUBOT_UNIFI_USER,
    password: process.env.HUBOT_UNIFI_PASS,
    insecure: true
  })

  robot.unifi.on 'wu.connected', (data) ->
    user = robot.presence.userWithMAC data.user
    if robot.brain.data.users[user].presence.enabled
      name = robot.brain.userForId(user).real_name
      if data.time >= robot.brain.data.users[user].presence.lastEntry + presenceNotificationDelay
        robot.messageRoom "#"+process.env.HUBOT_PRESENCE_ROOM, name + " is at the space now!"
        console.log "user connected"
      else
        console.log "delayed due to timeout"
      robot.brain.data.users[user].presence.lastEntry = data.time
      robot.brain.data.users[user].presence.atSpace = true
      robot.emit "memberPresent", user

  robot.unifi.on 'wu.disconnected', (data) ->
    user = robot.presence.userWithMAC data.user
    if robot.brain.data.users[user].presence.enabled
      robot.brain.data.users[user].presence.lastEntry = data.time
    robot.brain.data.users[user].presence.atSpace = false
    console.log "user disconnected"
    robot.emit "memberLeft", user

  robot.respond /setup presence/i, (res) ->
    user = robot.brain.userForName res.envelope.user.name
    if not user.presence
      user.presence = {}
      user.presence.enabled = true
      user.presence.devices = []
    if user.presence.accessToken
      robot.messageRoom "@"+res.envelope.user.name, "You've already started adding a device"
    else
      user.presence.accessToken = uuid()
      robot.messageRoom "@"+res.envelope.user.name, "Cool, let's get your new device connected"
    robot.messageRoom "@"+res.envelope.user.name, "Go to http://makey.localdomain/hubot/presence/addDevice?id="+user.presence.accessToken
    robot.messageRoom "@"+res.envelope.user.name, "And follow the instructions there"

  robot.respond /disable presence/i, (res) ->
    robot.messageRoom "@"+res.envelope.user.name, "Ok, I'll disable presence for you."
    user = robot.brain.userForName res.envelope.user.name
    user.presence?.enabled = false

  robot.respond /enable presence/i, (res) ->
    robot.messageRoom "@"+res.envelope.user.name, "Ok, I'll enable presence for you."
    user = robot.brain.userForName res.envelope.user.name
    user.presence?.enabled = true

  robot.respond /clear all presence devices/i, (res) ->
    robot.messageRoom "@"+res.envelope.user.name, "Deleting all your presence devices."
    user = robot.brain.userForName res.envelope.user.name
    user.presence.devices = []

  robot.respond /(who is|who's) at the space/i, (res) ->
    room = robot.adapter.client.rtm.dataStore.getChannelGroupOrDMById res.message.room
    present = robot.presence.usersPresent()
    response = if present == 1 then 'There is 1 member at the space' else if present == 0 then 'Nobody is at the space' else 'There are '+present+' members at the space.'
    if room.user == res.envelope.user.id
      res.send response
    if room.name == process.env.HUBOT_PRESENCE_ROOM
      res.send response

  refreshUsers = ->
    console.log "Refreshing Users"
    robot.emit "memberRefresh", false
    for user of robot.brain.data.users
      if robot.brain.data.users[user].presence
        robot.brain.data.users[user].presence.atSpace = false
        robot.emit "memberLeft", user
    robot.unifi.get('stat/sta').then (data) ->
      for user of data.data
        mac = data.data[user].mac
        user = robot.presence.userWithMAC(mac)
        if user
          robot.brain.data.users[user].presence.atSpace = true
          robot.emit "memberPresent", user
    robot.emit "memberRefreshDone", true

  tz = 'America/Chicago'
  new cronJob('0 */15 * * * *', refreshUsers, null, true, tz, robot, true)

  getMAC = (ip) ->
    return robot.unifi.get('stat/sta').then (data)->
      for user of data.data
        if data.data[user].ip == ip
          return data.data[user].mac

  robot.router.get "/hubot/presence/addDevice", (request, response) ->
    user = robot.presence.userToken request.query.id
    if user
      getMAC(request.ip)
        .then (mac) ->
          if mac
            userObj = robot.brain.data.users[user]
            robot.brain.data.users[user].presence.devices.push(mac)
            response.send('Added '+mac)
            robot.brain.data.users[user].presence.accessToken = ""

  robot.router.get "/hubot/presence/delDevice", (request, response) ->
    user = robot.presence.userToken request.query.id
    if user
      getMAC(request.ip)
        .then (mac) ->
          if mac
            userObj = robot.brain.data.users[user]
            index = userObj.presence.devices.indexOf(mac)
            if index >= 0
              userObj.presence.devices.splice(index,1)
            response.send('Removed '+mac)
            robot.brain.data.users[user].presence.accessToken = ""
