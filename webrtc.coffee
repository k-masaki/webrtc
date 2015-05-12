Tasks = new (Mongo.Collection)('tasks')
if Meteor.isClient
  Meteor.subscribe 'tasks'

  # This code only runs on the client
  Template.body.helpers
    tasks: ->
      if Session.get 'hideCompleted'
        Tasks.find {checked: {$ne: true}}, {sort: {createdAt: -1}}
      else
        Tasks.find {}, {sort: {createdAt: -1}}

    hideCompleted: ->
      Session.get 'hideCompleted'

    incompleteCount: ->
      Tasks.find(checked: {$ne: true}).count()

  Template.body.events
    'submit .new-task': (event)->
      # This function is called when the new task form is submitted
      text = event.target.text.value
      Meteor.call 'addTask', text

      # Clear form
      event.target.text.value = ''
      # Prevent default form submit
      false

    'change .hide-completed input': (event)->
      Session.set 'hideCompleted', event.target.checked

  Template.task.events
    'click .toggle-checked': ->
      Meteor.call 'setChecked', @_id, !@checked

    'click .delete': ->
      Meteor.call 'deleteTask', @_id

    'click .toggle-private': ->
      Meteor.call 'setPrivate', @_id, !@private

  Template.task.helpers
    isOwner: ->
      this.owner == Meteor.userId()

  Accounts.ui.config
    passwordSignupFields: 'USERNAME_ONLY'

if Meteor.isServer
  Meteor.publish 'tasks', ->
    Tasks.find
      $or: [
        {private: {$ne: true}}
        {owner: @userId}
      ]

Meteor.methods
  addTask: (text)->
    # Make sure the user is logged in before inserting a task
    if !Meteor.userId()
      throw new Meteor.Error 'not-authorized'
    Tasks.insert
      text: text
      createdAt: new Date
      owner: Meteor.userId()
      username: Meteor.user().username

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

