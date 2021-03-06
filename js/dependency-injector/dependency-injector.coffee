_ = require 'underscore' if require?

# Simple dependency injection.
class DependencyInjector
  initializeDi: ->
    [@registry, @initializers] = [{}, {}]
    [@application_scope, @custom_scopes] = [{}, {}]
    [@callbacks, @scope_callbacks] = [{}, {}]

  register: (name, args...) ->
    initializer = if _.isFunction(_(args).last()) then args.pop() else null
    scope = _(args).first() || 'application'

    @registry[name] = scope
    @initializers[name] = initializer

    # Generating shortcut.
    @constructor.prototype[name] = -> @get name
    setter = "set" + name[0].toUpperCase() + name[1..name.length]
    @constructor.prototype[setter] = (value) -> @set name, value

  set: (name, component) ->
    throw new Error(msg) "can't assign null as #{name} component!" unless component
    scope = @registry[name] || @_raise("component :#{name} not registered!")

    if scope == 'application'
      @application_scope[name] = component
    else if scope == 'instance'
      # Do nothing.
    else
      # Custom scope.
      container = @custom_scopes[scope] || @_raise("scope '#{scope}' for '#{name}' not started!")
      container[name] = component

    @_runCallbacks name, component
    component

  get: (name) ->
    scope = @registry[name] || @_raise("component :#{name} not registered!")

    if scope == 'application'
      @application_scope[name] || @_create(name, @application_scope)
    else if scope == 'instance'
      @_create name
    else
      # Custom scope.
      container = @custom_scopes[scope] || @_raise("scope '#{scope}' for '#{name}' not started!")
      container[name] || @_create(name, container)

  include: (name) ->
    return false unless scope = @registry[name]

    if scope == 'application'
      name of @application_scope
    else if scope == 'instance'
      false
    else
      # Custom scope.
      container = @custom_scopes[scope] || @_raise("scope '#{scope}' for '#{name}' not started!")
      name of container

  after: (name, callback) ->
    (@callbacks[name] ||= []).push callback
    # Immediatelly fire it if component already instantiated.
    callback(@get(name)) if @include name

  # Custom scopes.

  beginScope: (scope_name, container = {}) ->
    @custom_scopes[scope_name] = container
    @_runScopeCallbacks scope_name

  endScope: (scope_name) ->
    value = @custom_scopes[scope_name]
    delete @custom_scopes[scope_name]
    value

  afterScope: (scope_name, callback) ->
    (@scope_callbacks[scope_name] ||= []).push callback
    # Immediatelly fire it if scope already instantiated.
    callback() if scope_name of @custom_scopes

  _create: (name, container) ->
    initializer = @initializers[name] || @_raise("no initializer for #{name}!")
    component = initializer() || @_raise("initializer for #{name} returns null!")
    container[name] = component if container
    @_runCallbacks name, component
    component

  _runCallbacks: (name, component) ->
    _(callbacks).each((fun) -> fun(component)) if callbacks = @callbacks[name]

  _runScopeCallbacks: (scope_name) ->
    _(callbacks).each((fun) -> fun()) if callbacks = @scope_callbacks[scope_name]

  _raise: (msg) -> throw new Error(msg)

module.exports = DependencyInjector if module? and module.exports?
window.DependencyInjector = DependencyInjector if window?