Contacts = new Mongo.Collection 'contacts'
Messages = new Mongo.Collection 'messages'
States   = new Mongo.Collection 'states'

apiKey   = 'scgmaljt0tg1fw29'

if Meteor.isClient
  Meteor.subscribe 'states'

  Template.body.helpers

  Template.body.events

  Template.support.onCreated ->
    @subscribe 'contacts'

  Template.support.helpers
    connect: ->
      Session.get('page') == 'connecting'

  Template.supportDefault.helpers
    contacts: ->
      if Session.get 'onlyMe'
        Contacts.find {userId: Meteor.userId()}, {sort: {createdAt: -1}}
      else
        Contacts.find {}, {sort: {createdAt: -1}}

    onlyMe: ->
      Session.get 'onlyMe'

    myStateMessage: ->
      switch States.findOne(userId: Meteor.userId())?.type
        when 'away'  then '離席中'
        when 'chat'  then 'テキストチャットのみ'
        when 'audio' then 'ボイスチャット可'
        when 'video' then 'ビデオチャット可'

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
          Session.set 'page', 'connecting'
          call.on 'stream', (remoteStream)->
            Meteor.setTimeout ->
              localVideo = document.getElementById 'localVideo'
              localVideo.src = window.URL.createObjectURL stream
              remoteVideo = document.getElementById 'remoteVideo'
              remoteVideo.src = window.URL.createObjectURL remoteStream
            , 500
      ), (err) ->
        console.log 'Failed to get local stream', err
    peer.on 'connection', (conn)->
      Meteor.setTimeout ->
        conn.send Session.get('contactId')
      , 500

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

  Template.customer.events

  Template.customerDefault.helpers

  Template.customerDefault.events
    'click .open-video': ->
      peer = new Peer key: apiKey
      navigator.getUserMedia ||= navigator.webkitGetUserMedia || navigator.mozGetUserMedia
      navigator.getUserMedia {
        video: true
        audio: true
      }, ((stream)->
        support = States.findOne type: 'video'
        unless support
          alert '現在対応できるものがおりません。しばらくしてから再度お問い合わせください'
          return
        Session.set 'page', 'calling'
        call = peer.call support.userId, stream
        call.on 'stream', (remoteStream, contactId)->
          conn = peer.connect support.userId
          conn.on 'open', ->
            conn.on 'data', (contactId)->
              Session.set 'contactId', contactId
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
      peer = new Peer key: apiKey
      navigator.getUserMedia ||= navigator.webkitGetUserMedia || navigator.mozGetUserMedia
      navigator.getUserMedia {
        video: false
        audio: true
      }, ((stream)->
        support = States.findOne $or: [{type: 'video'}, {type: 'audio'}]
        unless support
          alert '現在対応できるものがおりません。しばらくしてから再度お問い合わせください'
          return
        Session.set 'page', 'calling'
        call = peer.call support.userId, stream
        call.on 'stream', (remoteStream, contactId)->
          Session.set 'contactId', contactId
          Session.set 'page', 'connecting'
          Meteor.setTimeout ->
            localVideo = document.getElementById 'localVideo'
            localVideo.src = window.URL.createObjectURL stream
            remoteVideo = document.getElementById 'remoteVideo'
            remoteVideo.src = window.URL.createObjectURL remoteStream
          , 500
      ), (err)->
        console.log 'Failed to get local stream', err

    'click .open-chat': ->


  Template.contact.helpers

  Template.contact.events

  Template.calling.helpers

  Template.calling.events

  Template.connecting.onCreated ->
    @subscribe 'messages', Session.get('contactId')

  Template.connecting.helpers
    messages: ->
      Messages.find()

  Template.connecting.events
    'submit .new-message': (event)=>
      text = event.target.text.value
      Meteor.call 'addMessage', Session.get('contactId'), null, text
      event.target.text.value = ''
      false

    'click .close': ->

  Template.message.helpers

  Template.message.events


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
  deleteTask: (taskId)->
    task = Tasks.findOne taskId
    if task.private && task.owner != Meteor.userId()
      throw new Meteor.Error 'not-authorized'
    Tasks.remove taskId

  setChecked: (taskId, setChecked)->
    task = Tasks.findOne taskId
    if task.private && task.owner != Meteor.userId()
      throw new Meteor.Error 'not-authorized'
    Tasks.update taskId, $set: checked: setChecked

  setPrivate: (taskId, setToPrivate)->
    task = Tasks.findOne taskId

    if task.owner != Meteor.userId()
      throw new Meteor.error 'not-authorized'

    Tasks.update taskId, {$set: {private: setToPrivate}}

  addContact: (type)->
    unless Meteor.userId()
      throw new Meteor.Error 'not-authorized'
    Contacts.insert
      userId: Meteor.userId()
      type: type

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

