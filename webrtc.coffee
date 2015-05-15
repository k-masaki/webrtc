Contacts = new Mongo.Collection 'contacts'
Messages = new Mongo.Collection 'messages'
States   = new Mongo.Collection 'states'

apiKey   = 'scgmaljt0tg1fw29'

if Meteor.isClient
  Meteor.subscribe 'states'

  Template.support.onCreated ->
    @subscribe 'contacts'
    Meteor.call 'updateState', null, 'wating'

  Template.support.helpers
    connect: ->
      Session.get('page') == 'connecting'

  Template.supportDefault.onCreated ->
    peer = new Peer Meteor.userId(), key: apiKey
    navigator.getUserMedia ||= navigator.webkitGetUserMedia || navigator.mozGetUserMedia
    peer.on 'call', (call)->
      navigator.getUserMedia {
        video: true
        audio: true
      }, ((stream)->
        Meteor.call 'addContact', (error, contactId)->
          Session.set 'contactId', contactId
          call.answer stream, contactId
          call.on 'stream', (remoteStream)->
            Session.set 'type', (if remoteStream.getVideoTracks().length then 'video' else 'audio')
            Session.set 'page', 'connecting'
            Meteor.call 'updateContactType', contactId, Session.get('type')
            Meteor.setTimeout ->
              if Session.get('type') == 'video'
                localVideo = document.getElementById 'localVideo'
                localVideo.src = window.URL.createObjectURL stream
                remoteVideo = document.getElementById 'remoteVideo'
                remoteVideo.src = window.URL.createObjectURL remoteStream
              else if Session.get('type') == 'audio'
                localAudio = document.getElementById 'localAudio'
                localAudio.src = window.URL.createObjectURL stream
                remoteAudio = document.getElementById 'remoteAudio'
                remoteAudio.src = window.URL.createObjectURL remoteStream
            , 500
      ), (err) ->
        console.log 'Failed to get local stream', err
    peer.on 'connection', (conn)->
      Meteor.setTimeout ->
        conn.send Session.get('contactId')
      , 500

  Template.supportDefault.helpers
    contacts: ->
      if Session.get 'onlyMe'
        Contacts.find {userId: Meteor.userId()}, {sort: {createdAt: -1}}
      else
        Contacts.find {}, {sort: {createdAt: -1}}

    onlyMe: ->
      Session.get 'onlyMe'

    myStateIsAway: ->
      States.findOne(userId: Meteor.userId())?.type == 'away'

    myStateIsChat: ->
      States.findOne(userId: Meteor.userId())?.type == 'chat'

    myStateIsAudio: ->
      States.findOne(userId: Meteor.userId())?.type == 'audio'

    myStateIsVideo: ->
      States.findOne(userId: Meteor.userId())?.type == 'video'

    myStateMessage: ->
      switch States.findOne(userId: Meteor.userId())?.type
        when 'away'  then '離席中'
        when 'chat'  then 'テキストチャットのみ'
        when 'audio' then 'ボイスチャット可'
        when 'video' then 'ビデオチャット可'

  Template.supportDefault.events
    'click .state-away': ->
      Meteor.call 'updateState', 'away'

    'click .state-chat': ->
      Meteor.call 'updateState', 'chat'

    'click .state-audio': ->
      Meteor.call 'updateState', 'audio'

    'click .state-video': ->
      Meteor.call 'updateState', 'video'

    'click .toggle-only-me': (event)->
      Session.set 'onlyMe', event.target.checked

  Template.customer.helpers
    connect: ->
      Session.get('page') == 'connecting'

    calling: ->
      Session.get('page') == 'calling'

  Template.customerDefault.helpers
    videoStatus: ->
      !!States.findOne {type: 'video', connecting: 'wating'}

    audioStatus: ->
      !!States.findOne {$or: [{type: 'video'}, {type: 'audio'}], connecting: 'wating'}

    chatStatus: ->
      false

  Template.customerDefault.events
    'click .open-video': ->
      support = States.findOne {type: 'video', connecting: 'wating'}
      unless support
        alert '現在対応できるものがおりません。しばらくしてから再度お問い合わせください'
        return
      peer = new Peer key: apiKey
      navigator.getUserMedia ||= navigator.webkitGetUserMedia || navigator.mozGetUserMedia
      navigator.getUserMedia {
        video: true
        audio: true
      }, ((stream)->
        support = States.findOne {type: 'video', connecting: 'wating'}
        unless support
          alert '現在対応できるものがおりません。しばらくしてから再度お問い合わせください'
          return
        # Session.set 'page', 'calling'
        call = peer.call support.userId, stream
        call.on 'stream', (remoteStream, contactId)->
          conn = peer.connect support.userId
          conn.on 'open', ->
            conn.on 'data', (contactId)->
              Session.set 'contactId', contactId
              Session.set 'type', 'video'
              Session.set 'page', 'connecting'
              Meteor.setTimeout ->
                localVideo = document.getElementById 'localVideo'
                localVideo.src = window.URL.createObjectURL stream
                remoteVideo = document.getElementById 'remoteVideo'
                remoteVideo.src = window.URL.createObjectURL remoteStream
              , 500
      ), (err)->
        console.log 'Failed to get local stream', err

    'click .open-audio': ->
      support = States.findOne {$or: [{type: 'video'}, {type: 'audio'}], connecting: 'wating'}
      unless support
        alert '現在対応できるものがおりません。しばらくしてから再度お問い合わせください'
        return
      peer = new Peer key: apiKey
      navigator.getUserMedia ||= navigator.webkitGetUserMedia || navigator.mozGetUserMedia
      navigator.getUserMedia {
        video: false
        audio: true
      }, ((stream)->
        support = States.findOne {$or: [{type: 'video'}, {type: 'audio'}], connecting: 'wating'}
        unless support
          alert '現在対応できるものがおりません。しばらくしてから再度お問い合わせください'
          return
        # Session.set 'page', 'calling'
        call = peer.call support.userId, stream
        call.on 'stream', (remoteStream, contactId)->
          conn = peer.connect support.userId
          conn.on 'open', ->
            conn.on 'data', (contactId)->
              Session.set 'contactId', contactId
              Session.set 'type', 'audio'
              Session.set 'page', 'connecting'
              Meteor.setTimeout ->
                localAudio = document.getElementById 'localAudio'
                localAudio.src = window.URL.createObjectURL stream
                remoteAudio = document.getElementById 'remoteAudio'
                remoteAudio.src = window.URL.createObjectURL remoteStream
              , 500
      ), (err)->
        console.log 'Failed to get local stream', err

    'click .open-chat': ->
      alert '現在対応できるものがおりません。しばらくしてから再度お問い合わせください'


  Template.contact.helpers
    time: ->
      @createdAt.toLocaleString()

    typeStr: ->
      switch @type
        when 'video' then 'ビデオチャット'
        when 'audio' then 'ボイスチャット'
        when 'chat' then 'テキストチャット'

    support: ->
      @username

  Template.connecting.onCreated ->
    @subscribe 'messages', Session.get('contactId')
    if Meteor.userId()
      Meteor.call 'updateState', null, 'connecting'

  Template.connecting.helpers
    messages: ->
      Messages.find()

    isVideo: ->
      Session.get('type') == 'video'

    isAudio: ->
      Session.get('type') == 'audio'

  Template.connecting.events
    'submit .new-message': (event)=>
      text = event.target.text.value
      return false unless text
      Meteor.call 'addMessage', Session.get('contactId'), null, text
      event.target.text.value = ''
      false

  Template.message.onRendered ->
    obj = document.body
    return unless obj
    obj.scrollTop = obj.scrollHeight

  Template.message.helpers
    name: ->
      if Meteor.userId()
        if @userId
          'サポート'
        else
          'お客様'
      else
        if @userId
          'サポート'
        else
          'あなた'

  Accounts.ui.config
    passwordSignupFields: 'USERNAME_ONLY'

if Meteor.isServer
  Meteor.publish 'contacts', ->
    unless @userId
      throw new Meteor.Error 'not-authorized'
    Contacts.find()

  Meteor.publish 'messages', (contactId)->
    Messages.find {contactId: contactId}

  Meteor.publish 'states', ->
    States.find()

Meteor.methods
  addContact: (type=null)->
    unless Meteor.userId()
      throw new Meteor.Error 'not-authorized'
    Contacts.insert
      userId: Meteor.userId()
      username: Meteor.user().username
      type: type
      createdAt: new Date

  updateContactType: (id, type)->
    contact = Contacts.findOne _id: id, userId: Meteor.userId()
    unless contact
     throw new Meteor.Error 'not-found'
    Contacts.update id, {$set: {type: type}}

  addMessage: (contactId, action, text)->
    contact = Contacts.findOne contactId
    unless contact
      throw new Meteor.Error 'not-authorized'
    Messages.insert
      contactId: contactId
      action: action
      text: text
      createdAt: new Date
      userId: Meteor.userId()

  updateState: (type=null, connecting=null)->
    userId = Meteor.userId()
    unless userId
      throw new Meteor.Error 'not-authorized'
    state = States.findOne userId: userId
    if state
      unless type == null
        States.update state._id, {$set: {type: type}}
      unless connecting == null
        States.update state._id, {$set: {connecting: connecting}}
    else
      States.insert
        userId: userId
        type: type
        connecting: connecting

orgLogout = Meteor.logout
Meteor.logout = (func)->
  Meteor.call 'updateState', null, 'logout'
  orgLogout func
