/*eslint-disable block-scoped-var, id-length, no-control-regex, no-magic-numbers, no-mixed-operators, no-prototype-builtins, no-redeclare, no-shadow, no-var, sort-vars, default-case, jsdoc/require-param*/
"use strict";

var $protobuf = require("protobufjs/minimal");

// Common aliases
var $Reader = $protobuf.Reader, $Writer = $protobuf.Writer, $util = $protobuf.util;
var $Object = $util.global.Object, $undefined = $util.global.undefined, $Error = $util.global.Error, $TypeError = $util.global.TypeError, $Number = $util.global.Number, $String = $util.global.String, $isFinite = $util.global.isFinite, $Boolean = $util.global.Boolean, $parseInt = $util.global.parseInt, $BigInt = $util.global.BigInt;

// Exported root namespace
var $root = $protobuf.roots["default"] || ($protobuf.roots["default"] = {});

$root.warbase = (function() {

    /**
     * Namespace warbase.
     * @exports warbase
     * @namespace
     */
    var warbase = {};

    warbase.ClientEvent = (function() {

        /**
         * Properties of a ClientEvent.
         * @typedef {Object} warbase.ClientEvent.$Properties
         * @property {warbase.PlayerStateUpdate.$Properties|null} [stateUpdate] ClientEvent stateUpdate
         * @property {warbase.HitEvent.$Properties|null} [hit] ClientEvent hit
         * @property {warbase.FireEvent.$Properties|null} [fire] ClientEvent fire
         * @property {warbase.ReloadEvent.$Properties|null} [reload] ClientEvent reload
         * @property {warbase.SwitchWeaponEvent.$Properties|null} [switchWeapon] ClientEvent switchWeapon
         * @property {warbase.RespawnRequestEvent.$Properties|null} [respawnRequest] ClientEvent respawnRequest
         * @property {warbase.ThrowGrenadeEvent.$Properties|null} [throwGrenade] ClientEvent throwGrenade
         * @property {warbase.PingEvent.$Properties|null} [ping] ClientEvent ping
         * @property {"stateUpdate"|"hit"|"fire"|"reload"|"switchWeapon"|"respawnRequest"|"throwGrenade"|"ping"} [event] ClientEvent event
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a ClientEvent.
         * @memberof warbase
         * @interface IClientEvent
         * @augments warbase.ClientEvent.$Properties
         * @deprecated Use warbase.ClientEvent.$Properties instead.
         */

        /**
         * Narrowed shape of a ClientEvent.
         * @typedef {{
         *   stateUpdate?: warbase.PlayerStateUpdate.$Shape|null;
         *   hit?: warbase.HitEvent.$Shape|null;
         *   fire?: warbase.FireEvent.$Shape|null;
         *   reload?: warbase.ReloadEvent.$Shape|null;
         *   switchWeapon?: warbase.SwitchWeaponEvent.$Shape|null;
         *   respawnRequest?: warbase.RespawnRequestEvent.$Shape|null;
         *   throwGrenade?: warbase.ThrowGrenadeEvent.$Shape|null;
         *   ping?: warbase.PingEvent.$Shape|null;
         *   $unknowns?: Array.<Uint8Array>;
         * } & (
         *   ({ event?: undefined; stateUpdate?: null; hit?: null; fire?: null; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "stateUpdate"; stateUpdate: warbase.PlayerStateUpdate.$Shape; hit?: null; fire?: null; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "hit"; stateUpdate?: null; hit: warbase.HitEvent.$Shape; fire?: null; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "fire"; stateUpdate?: null; hit?: null; fire: warbase.FireEvent.$Shape; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "reload"; stateUpdate?: null; hit?: null; fire?: null; reload: warbase.ReloadEvent.$Shape; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "switchWeapon"; stateUpdate?: null; hit?: null; fire?: null; reload?: null; switchWeapon: warbase.SwitchWeaponEvent.$Shape; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "respawnRequest"; stateUpdate?: null; hit?: null; fire?: null; reload?: null; switchWeapon?: null; respawnRequest: warbase.RespawnRequestEvent.$Shape; throwGrenade?: null; ping?: null }|{ event?: "throwGrenade"; stateUpdate?: null; hit?: null; fire?: null; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade: warbase.ThrowGrenadeEvent.$Shape; ping?: null }|{ event?: "ping"; stateUpdate?: null; hit?: null; fire?: null; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping: warbase.PingEvent.$Shape })
         * )} warbase.ClientEvent.$Shape
         */

        /**
         * Constructs a new ClientEvent.
         * @memberof warbase
         * @classdesc Represents a ClientEvent.
         * @constructor
         * @param {warbase.ClientEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var ClientEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * ClientEvent stateUpdate.
         * @member {warbase.PlayerStateUpdate.$Properties|null|undefined} stateUpdate
         * @memberof warbase.ClientEvent
         * @instance
         */
        ClientEvent.prototype.stateUpdate = null;

        /**
         * ClientEvent hit.
         * @member {warbase.HitEvent.$Properties|null|undefined} hit
         * @memberof warbase.ClientEvent
         * @instance
         */
        ClientEvent.prototype.hit = null;

        /**
         * ClientEvent fire.
         * @member {warbase.FireEvent.$Properties|null|undefined} fire
         * @memberof warbase.ClientEvent
         * @instance
         */
        ClientEvent.prototype.fire = null;

        /**
         * ClientEvent reload.
         * @member {warbase.ReloadEvent.$Properties|null|undefined} reload
         * @memberof warbase.ClientEvent
         * @instance
         */
        ClientEvent.prototype.reload = null;

        /**
         * ClientEvent switchWeapon.
         * @member {warbase.SwitchWeaponEvent.$Properties|null|undefined} switchWeapon
         * @memberof warbase.ClientEvent
         * @instance
         */
        ClientEvent.prototype.switchWeapon = null;

        /**
         * ClientEvent respawnRequest.
         * @member {warbase.RespawnRequestEvent.$Properties|null|undefined} respawnRequest
         * @memberof warbase.ClientEvent
         * @instance
         */
        ClientEvent.prototype.respawnRequest = null;

        /**
         * ClientEvent throwGrenade.
         * @member {warbase.ThrowGrenadeEvent.$Properties|null|undefined} throwGrenade
         * @memberof warbase.ClientEvent
         * @instance
         */
        ClientEvent.prototype.throwGrenade = null;

        /**
         * ClientEvent ping.
         * @member {warbase.PingEvent.$Properties|null|undefined} ping
         * @memberof warbase.ClientEvent
         * @instance
         */
        ClientEvent.prototype.ping = null;

        // OneOf field names bound to virtual getters and setters
        var $oneOfFields;

        /**
         * ClientEvent event.
         * @member {"stateUpdate"|"hit"|"fire"|"reload"|"switchWeapon"|"respawnRequest"|"throwGrenade"|"ping"|undefined} event
         * @memberof warbase.ClientEvent
         * @instance
         */
        $Object.defineProperty(ClientEvent.prototype, "event", {
            get: $util.oneOfGetter($oneOfFields = ["stateUpdate", "hit", "fire", "reload", "switchWeapon", "respawnRequest", "throwGrenade", "ping"]),
            set: $util.oneOfSetter($oneOfFields)
        });

        /**
         * Creates a new ClientEvent instance using the specified properties.
         * @function create
         * @memberof warbase.ClientEvent
         * @static
         * @param {warbase.ClientEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.ClientEvent} ClientEvent instance
         * @type {{
         *   (properties: warbase.ClientEvent.$Shape): warbase.ClientEvent & warbase.ClientEvent.$Shape;
         *   (properties?: warbase.ClientEvent.$Properties): warbase.ClientEvent;
         * }}
         */
        ClientEvent.create = function(properties) {
            return new ClientEvent(properties);
        };

        /**
         * Encodes the specified ClientEvent message. Does not implicitly {@link warbase.ClientEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.ClientEvent
         * @static
         * @param {warbase.ClientEvent.$Properties} message ClientEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ClientEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.stateUpdate != null && $Object.hasOwnProperty.call(message, "stateUpdate"))
                $root.warbase.PlayerStateUpdate.encode(message.stateUpdate, writer.uint32(/* id 1, wireType 2 =*/10).fork(), _depth + 1).ldelim();
            if (message.hit != null && $Object.hasOwnProperty.call(message, "hit"))
                $root.warbase.HitEvent.encode(message.hit, writer.uint32(/* id 2, wireType 2 =*/18).fork(), _depth + 1).ldelim();
            if (message.fire != null && $Object.hasOwnProperty.call(message, "fire"))
                $root.warbase.FireEvent.encode(message.fire, writer.uint32(/* id 3, wireType 2 =*/26).fork(), _depth + 1).ldelim();
            if (message.reload != null && $Object.hasOwnProperty.call(message, "reload"))
                $root.warbase.ReloadEvent.encode(message.reload, writer.uint32(/* id 4, wireType 2 =*/34).fork(), _depth + 1).ldelim();
            if (message.switchWeapon != null && $Object.hasOwnProperty.call(message, "switchWeapon"))
                $root.warbase.SwitchWeaponEvent.encode(message.switchWeapon, writer.uint32(/* id 5, wireType 2 =*/42).fork(), _depth + 1).ldelim();
            if (message.respawnRequest != null && $Object.hasOwnProperty.call(message, "respawnRequest"))
                $root.warbase.RespawnRequestEvent.encode(message.respawnRequest, writer.uint32(/* id 6, wireType 2 =*/50).fork(), _depth + 1).ldelim();
            if (message.throwGrenade != null && $Object.hasOwnProperty.call(message, "throwGrenade"))
                $root.warbase.ThrowGrenadeEvent.encode(message.throwGrenade, writer.uint32(/* id 7, wireType 2 =*/58).fork(), _depth + 1).ldelim();
            if (message.ping != null && $Object.hasOwnProperty.call(message, "ping"))
                $root.warbase.PingEvent.encode(message.ping, writer.uint32(/* id 8, wireType 2 =*/66).fork(), _depth + 1).ldelim();
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified ClientEvent message, length delimited. Does not implicitly {@link warbase.ClientEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.ClientEvent
         * @static
         * @param {warbase.ClientEvent.$Properties} message ClientEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ClientEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a ClientEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.ClientEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.ClientEvent & warbase.ClientEvent.$Shape} ClientEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ClientEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.ClientEvent();
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 2)
                            break;
                        message.stateUpdate = $root.warbase.PlayerStateUpdate.decode(reader, reader.uint32(), $undefined, _depth + 1, message.stateUpdate);
                        message.event = "stateUpdate";
                        continue;
                    }
                case 2: {
                        if (wireType !== 2)
                            break;
                        message.hit = $root.warbase.HitEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.hit);
                        message.event = "hit";
                        continue;
                    }
                case 3: {
                        if (wireType !== 2)
                            break;
                        message.fire = $root.warbase.FireEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.fire);
                        message.event = "fire";
                        continue;
                    }
                case 4: {
                        if (wireType !== 2)
                            break;
                        message.reload = $root.warbase.ReloadEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.reload);
                        message.event = "reload";
                        continue;
                    }
                case 5: {
                        if (wireType !== 2)
                            break;
                        message.switchWeapon = $root.warbase.SwitchWeaponEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.switchWeapon);
                        message.event = "switchWeapon";
                        continue;
                    }
                case 6: {
                        if (wireType !== 2)
                            break;
                        message.respawnRequest = $root.warbase.RespawnRequestEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.respawnRequest);
                        message.event = "respawnRequest";
                        continue;
                    }
                case 7: {
                        if (wireType !== 2)
                            break;
                        message.throwGrenade = $root.warbase.ThrowGrenadeEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.throwGrenade);
                        message.event = "throwGrenade";
                        continue;
                    }
                case 8: {
                        if (wireType !== 2)
                            break;
                        message.ping = $root.warbase.PingEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.ping);
                        message.event = "ping";
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a ClientEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.ClientEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.ClientEvent & warbase.ClientEvent.$Shape} ClientEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ClientEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a ClientEvent message.
         * @function verify
         * @memberof warbase.ClientEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        ClientEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            var properties = {};
            if (message.stateUpdate != null && $Object.hasOwnProperty.call(message, "stateUpdate")) {
                properties.event = 1;
                {
                    var error = $root.warbase.PlayerStateUpdate.verify(message.stateUpdate, _depth + 1);
                    if (error)
                        return "stateUpdate." + error;
                }
            }
            if (message.hit != null && $Object.hasOwnProperty.call(message, "hit")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.HitEvent.verify(message.hit, _depth + 1);
                    if (error)
                        return "hit." + error;
                }
            }
            if (message.fire != null && $Object.hasOwnProperty.call(message, "fire")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.FireEvent.verify(message.fire, _depth + 1);
                    if (error)
                        return "fire." + error;
                }
            }
            if (message.reload != null && $Object.hasOwnProperty.call(message, "reload")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.ReloadEvent.verify(message.reload, _depth + 1);
                    if (error)
                        return "reload." + error;
                }
            }
            if (message.switchWeapon != null && $Object.hasOwnProperty.call(message, "switchWeapon")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.SwitchWeaponEvent.verify(message.switchWeapon, _depth + 1);
                    if (error)
                        return "switchWeapon." + error;
                }
            }
            if (message.respawnRequest != null && $Object.hasOwnProperty.call(message, "respawnRequest")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.RespawnRequestEvent.verify(message.respawnRequest, _depth + 1);
                    if (error)
                        return "respawnRequest." + error;
                }
            }
            if (message.throwGrenade != null && $Object.hasOwnProperty.call(message, "throwGrenade")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.ThrowGrenadeEvent.verify(message.throwGrenade, _depth + 1);
                    if (error)
                        return "throwGrenade." + error;
                }
            }
            if (message.ping != null && $Object.hasOwnProperty.call(message, "ping")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.PingEvent.verify(message.ping, _depth + 1);
                    if (error)
                        return "ping." + error;
                }
            }
            return null;
        };

        /**
         * Creates a ClientEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.ClientEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.ClientEvent} ClientEvent
         */
        ClientEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.ClientEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.ClientEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.ClientEvent();
            if (object.stateUpdate != null) {
                if (!$util.isObject(object.stateUpdate))
                    throw $TypeError(".warbase.ClientEvent.stateUpdate: object expected");
                message.stateUpdate = $root.warbase.PlayerStateUpdate.fromObject(object.stateUpdate, _depth + 1);
            }
            if (object.hit != null) {
                if (!$util.isObject(object.hit))
                    throw $TypeError(".warbase.ClientEvent.hit: object expected");
                message.hit = $root.warbase.HitEvent.fromObject(object.hit, _depth + 1);
            }
            if (object.fire != null) {
                if (!$util.isObject(object.fire))
                    throw $TypeError(".warbase.ClientEvent.fire: object expected");
                message.fire = $root.warbase.FireEvent.fromObject(object.fire, _depth + 1);
            }
            if (object.reload != null) {
                if (!$util.isObject(object.reload))
                    throw $TypeError(".warbase.ClientEvent.reload: object expected");
                message.reload = $root.warbase.ReloadEvent.fromObject(object.reload, _depth + 1);
            }
            if (object.switchWeapon != null) {
                if (!$util.isObject(object.switchWeapon))
                    throw $TypeError(".warbase.ClientEvent.switchWeapon: object expected");
                message.switchWeapon = $root.warbase.SwitchWeaponEvent.fromObject(object.switchWeapon, _depth + 1);
            }
            if (object.respawnRequest != null) {
                if (!$util.isObject(object.respawnRequest))
                    throw $TypeError(".warbase.ClientEvent.respawnRequest: object expected");
                message.respawnRequest = $root.warbase.RespawnRequestEvent.fromObject(object.respawnRequest, _depth + 1);
            }
            if (object.throwGrenade != null) {
                if (!$util.isObject(object.throwGrenade))
                    throw $TypeError(".warbase.ClientEvent.throwGrenade: object expected");
                message.throwGrenade = $root.warbase.ThrowGrenadeEvent.fromObject(object.throwGrenade, _depth + 1);
            }
            if (object.ping != null) {
                if (!$util.isObject(object.ping))
                    throw $TypeError(".warbase.ClientEvent.ping: object expected");
                message.ping = $root.warbase.PingEvent.fromObject(object.ping, _depth + 1);
            }
            return message;
        };

        /**
         * Creates a plain object from a ClientEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.ClientEvent
         * @static
         * @param {warbase.ClientEvent} message ClientEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        ClientEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (message.stateUpdate != null && $Object.hasOwnProperty.call(message, "stateUpdate")) {
                object.stateUpdate = $root.warbase.PlayerStateUpdate.toObject(message.stateUpdate, options, _depth + 1);
                if (options.oneofs)
                    object.event = "stateUpdate";
            }
            if (message.hit != null && $Object.hasOwnProperty.call(message, "hit")) {
                object.hit = $root.warbase.HitEvent.toObject(message.hit, options, _depth + 1);
                if (options.oneofs)
                    object.event = "hit";
            }
            if (message.fire != null && $Object.hasOwnProperty.call(message, "fire")) {
                object.fire = $root.warbase.FireEvent.toObject(message.fire, options, _depth + 1);
                if (options.oneofs)
                    object.event = "fire";
            }
            if (message.reload != null && $Object.hasOwnProperty.call(message, "reload")) {
                object.reload = $root.warbase.ReloadEvent.toObject(message.reload, options, _depth + 1);
                if (options.oneofs)
                    object.event = "reload";
            }
            if (message.switchWeapon != null && $Object.hasOwnProperty.call(message, "switchWeapon")) {
                object.switchWeapon = $root.warbase.SwitchWeaponEvent.toObject(message.switchWeapon, options, _depth + 1);
                if (options.oneofs)
                    object.event = "switchWeapon";
            }
            if (message.respawnRequest != null && $Object.hasOwnProperty.call(message, "respawnRequest")) {
                object.respawnRequest = $root.warbase.RespawnRequestEvent.toObject(message.respawnRequest, options, _depth + 1);
                if (options.oneofs)
                    object.event = "respawnRequest";
            }
            if (message.throwGrenade != null && $Object.hasOwnProperty.call(message, "throwGrenade")) {
                object.throwGrenade = $root.warbase.ThrowGrenadeEvent.toObject(message.throwGrenade, options, _depth + 1);
                if (options.oneofs)
                    object.event = "throwGrenade";
            }
            if (message.ping != null && $Object.hasOwnProperty.call(message, "ping")) {
                object.ping = $root.warbase.PingEvent.toObject(message.ping, options, _depth + 1);
                if (options.oneofs)
                    object.event = "ping";
            }
            return object;
        };

        /**
         * Converts this ClientEvent to JSON.
         * @function toJSON
         * @memberof warbase.ClientEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        ClientEvent.prototype.toJSON = function() {
            return ClientEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for ClientEvent
         * @function getTypeUrl
         * @memberof warbase.ClientEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        ClientEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.ClientEvent";
        };

        return ClientEvent;
    })();

    warbase.PlayerStateUpdate = (function() {

        /**
         * Properties of a PlayerStateUpdate.
         * @typedef {Object} warbase.PlayerStateUpdate.$Properties
         * @property {number|null} [x] PlayerStateUpdate x
         * @property {number|null} [y] PlayerStateUpdate y
         * @property {number|null} [z] PlayerStateUpdate z
         * @property {number|null} [rx] PlayerStateUpdate rx
         * @property {number|null} [ry] PlayerStateUpdate ry
         * @property {number|null} [rz] PlayerStateUpdate rz
         * @property {number|null} [rw] PlayerStateUpdate rw
         * @property {string|null} [animation] PlayerStateUpdate animation
         * @property {string|null} [platformId] PlayerStateUpdate platformId
         * @property {number|null} [ping] PlayerStateUpdate ping
         * @property {string|null} [weaponId] PlayerStateUpdate weaponId
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a PlayerStateUpdate.
         * @memberof warbase
         * @interface IPlayerStateUpdate
         * @augments warbase.PlayerStateUpdate.$Properties
         * @deprecated Use warbase.PlayerStateUpdate.$Properties instead.
         */

        /**
         * Shape of a PlayerStateUpdate.
         * @typedef {warbase.PlayerStateUpdate.$Properties} warbase.PlayerStateUpdate.$Shape
         */

        /**
         * Constructs a new PlayerStateUpdate.
         * @memberof warbase
         * @classdesc Represents a PlayerStateUpdate.
         * @constructor
         * @param {warbase.PlayerStateUpdate.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var PlayerStateUpdate = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * PlayerStateUpdate x.
         * @member {number} x
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.x = 0;

        /**
         * PlayerStateUpdate y.
         * @member {number} y
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.y = 0;

        /**
         * PlayerStateUpdate z.
         * @member {number} z
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.z = 0;

        /**
         * PlayerStateUpdate rx.
         * @member {number} rx
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.rx = 0;

        /**
         * PlayerStateUpdate ry.
         * @member {number} ry
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.ry = 0;

        /**
         * PlayerStateUpdate rz.
         * @member {number} rz
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.rz = 0;

        /**
         * PlayerStateUpdate rw.
         * @member {number} rw
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.rw = 0;

        /**
         * PlayerStateUpdate animation.
         * @member {string} animation
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.animation = "";

        /**
         * PlayerStateUpdate platformId.
         * @member {string} platformId
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.platformId = "";

        /**
         * PlayerStateUpdate ping.
         * @member {number} ping
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.ping = 0;

        /**
         * PlayerStateUpdate weaponId.
         * @member {string} weaponId
         * @memberof warbase.PlayerStateUpdate
         * @instance
         */
        PlayerStateUpdate.prototype.weaponId = "";

        /**
         * Creates a new PlayerStateUpdate instance using the specified properties.
         * @function create
         * @memberof warbase.PlayerStateUpdate
         * @static
         * @param {warbase.PlayerStateUpdate.$Properties=} [properties] Properties to set
         * @returns {warbase.PlayerStateUpdate} PlayerStateUpdate instance
         * @type {{
         *   (properties: warbase.PlayerStateUpdate.$Shape): warbase.PlayerStateUpdate & warbase.PlayerStateUpdate.$Shape;
         *   (properties?: warbase.PlayerStateUpdate.$Properties): warbase.PlayerStateUpdate;
         * }}
         */
        PlayerStateUpdate.create = function(properties) {
            return new PlayerStateUpdate(properties);
        };

        /**
         * Encodes the specified PlayerStateUpdate message. Does not implicitly {@link warbase.PlayerStateUpdate.verify|verify} messages.
         * @function encode
         * @memberof warbase.PlayerStateUpdate
         * @static
         * @param {warbase.PlayerStateUpdate.$Properties} message PlayerStateUpdate message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        PlayerStateUpdate.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.x != null && $Object.hasOwnProperty.call(message, "x") && !$Object.is(message.x, 0))
                writer.uint32(/* id 1, wireType 5 =*/13).float(message.x);
            if (message.y != null && $Object.hasOwnProperty.call(message, "y") && !$Object.is(message.y, 0))
                writer.uint32(/* id 2, wireType 5 =*/21).float(message.y);
            if (message.z != null && $Object.hasOwnProperty.call(message, "z") && !$Object.is(message.z, 0))
                writer.uint32(/* id 3, wireType 5 =*/29).float(message.z);
            if (message.rx != null && $Object.hasOwnProperty.call(message, "rx") && !$Object.is(message.rx, 0))
                writer.uint32(/* id 4, wireType 5 =*/37).float(message.rx);
            if (message.ry != null && $Object.hasOwnProperty.call(message, "ry") && !$Object.is(message.ry, 0))
                writer.uint32(/* id 5, wireType 5 =*/45).float(message.ry);
            if (message.rz != null && $Object.hasOwnProperty.call(message, "rz") && !$Object.is(message.rz, 0))
                writer.uint32(/* id 6, wireType 5 =*/53).float(message.rz);
            if (message.rw != null && $Object.hasOwnProperty.call(message, "rw") && !$Object.is(message.rw, 0))
                writer.uint32(/* id 7, wireType 5 =*/61).float(message.rw);
            if (message.animation != null && $Object.hasOwnProperty.call(message, "animation") && message.animation !== "")
                writer.uint32(/* id 8, wireType 2 =*/66).string(message.animation);
            if (message.platformId != null && $Object.hasOwnProperty.call(message, "platformId") && message.platformId !== "")
                writer.uint32(/* id 9, wireType 2 =*/74).string(message.platformId);
            if (message.ping != null && $Object.hasOwnProperty.call(message, "ping") && message.ping !== 0)
                writer.uint32(/* id 10, wireType 0 =*/80).int32(message.ping);
            if (message.weaponId != null && $Object.hasOwnProperty.call(message, "weaponId") && message.weaponId !== "")
                writer.uint32(/* id 11, wireType 2 =*/90).string(message.weaponId);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified PlayerStateUpdate message, length delimited. Does not implicitly {@link warbase.PlayerStateUpdate.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.PlayerStateUpdate
         * @static
         * @param {warbase.PlayerStateUpdate.$Properties} message PlayerStateUpdate message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        PlayerStateUpdate.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a PlayerStateUpdate message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.PlayerStateUpdate
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.PlayerStateUpdate & warbase.PlayerStateUpdate.$Shape} PlayerStateUpdate
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        PlayerStateUpdate.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.PlayerStateUpdate(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.x = value;
                        else
                            delete message.x;
                        continue;
                    }
                case 2: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.y = value;
                        else
                            delete message.y;
                        continue;
                    }
                case 3: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.z = value;
                        else
                            delete message.z;
                        continue;
                    }
                case 4: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.rx = value;
                        else
                            delete message.rx;
                        continue;
                    }
                case 5: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.ry = value;
                        else
                            delete message.ry;
                        continue;
                    }
                case 6: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.rz = value;
                        else
                            delete message.rz;
                        continue;
                    }
                case 7: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.rw = value;
                        else
                            delete message.rw;
                        continue;
                    }
                case 8: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.animation = value;
                        else
                            delete message.animation;
                        continue;
                    }
                case 9: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.platformId = value;
                        else
                            delete message.platformId;
                        continue;
                    }
                case 10: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.int32())
                            message.ping = value;
                        else
                            delete message.ping;
                        continue;
                    }
                case 11: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.weaponId = value;
                        else
                            delete message.weaponId;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a PlayerStateUpdate message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.PlayerStateUpdate
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.PlayerStateUpdate & warbase.PlayerStateUpdate.$Shape} PlayerStateUpdate
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        PlayerStateUpdate.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a PlayerStateUpdate message.
         * @function verify
         * @memberof warbase.PlayerStateUpdate
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        PlayerStateUpdate.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.x != null && $Object.hasOwnProperty.call(message, "x"))
                if (typeof message.x !== "number")
                    return "x: number expected";
            if (message.y != null && $Object.hasOwnProperty.call(message, "y"))
                if (typeof message.y !== "number")
                    return "y: number expected";
            if (message.z != null && $Object.hasOwnProperty.call(message, "z"))
                if (typeof message.z !== "number")
                    return "z: number expected";
            if (message.rx != null && $Object.hasOwnProperty.call(message, "rx"))
                if (typeof message.rx !== "number")
                    return "rx: number expected";
            if (message.ry != null && $Object.hasOwnProperty.call(message, "ry"))
                if (typeof message.ry !== "number")
                    return "ry: number expected";
            if (message.rz != null && $Object.hasOwnProperty.call(message, "rz"))
                if (typeof message.rz !== "number")
                    return "rz: number expected";
            if (message.rw != null && $Object.hasOwnProperty.call(message, "rw"))
                if (typeof message.rw !== "number")
                    return "rw: number expected";
            if (message.animation != null && $Object.hasOwnProperty.call(message, "animation"))
                if (!$util.isString(message.animation))
                    return "animation: string expected";
            if (message.platformId != null && $Object.hasOwnProperty.call(message, "platformId"))
                if (!$util.isString(message.platformId))
                    return "platformId: string expected";
            if (message.ping != null && $Object.hasOwnProperty.call(message, "ping"))
                if (!$util.isInteger(message.ping))
                    return "ping: integer expected";
            if (message.weaponId != null && $Object.hasOwnProperty.call(message, "weaponId"))
                if (!$util.isString(message.weaponId))
                    return "weaponId: string expected";
            return null;
        };

        /**
         * Creates a PlayerStateUpdate message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.PlayerStateUpdate
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.PlayerStateUpdate} PlayerStateUpdate
         */
        PlayerStateUpdate.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.PlayerStateUpdate)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.PlayerStateUpdate: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.PlayerStateUpdate();
            if (object.x != null)
                if (!$Object.is($Number(object.x), 0))
                    message.x = $Number(object.x);
            if (object.y != null)
                if (!$Object.is($Number(object.y), 0))
                    message.y = $Number(object.y);
            if (object.z != null)
                if (!$Object.is($Number(object.z), 0))
                    message.z = $Number(object.z);
            if (object.rx != null)
                if (!$Object.is($Number(object.rx), 0))
                    message.rx = $Number(object.rx);
            if (object.ry != null)
                if (!$Object.is($Number(object.ry), 0))
                    message.ry = $Number(object.ry);
            if (object.rz != null)
                if (!$Object.is($Number(object.rz), 0))
                    message.rz = $Number(object.rz);
            if (object.rw != null)
                if (!$Object.is($Number(object.rw), 0))
                    message.rw = $Number(object.rw);
            if (object.animation != null)
                if (typeof object.animation !== "string" || object.animation.length)
                    message.animation = $String(object.animation);
            if (object.platformId != null)
                if (typeof object.platformId !== "string" || object.platformId.length)
                    message.platformId = $String(object.platformId);
            if (object.ping != null)
                if ($Number(object.ping) !== 0)
                    message.ping = object.ping | 0;
            if (object.weaponId != null)
                if (typeof object.weaponId !== "string" || object.weaponId.length)
                    message.weaponId = $String(object.weaponId);
            return message;
        };

        /**
         * Creates a plain object from a PlayerStateUpdate message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.PlayerStateUpdate
         * @static
         * @param {warbase.PlayerStateUpdate} message PlayerStateUpdate
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        PlayerStateUpdate.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults) {
                object.x = 0;
                object.y = 0;
                object.z = 0;
                object.rx = 0;
                object.ry = 0;
                object.rz = 0;
                object.rw = 0;
                object.animation = "";
                object.platformId = "";
                object.ping = 0;
                object.weaponId = "";
            }
            if (message.x != null && $Object.hasOwnProperty.call(message, "x"))
                object.x = options.json && !$isFinite(message.x) ? $String(message.x) : message.x;
            if (message.y != null && $Object.hasOwnProperty.call(message, "y"))
                object.y = options.json && !$isFinite(message.y) ? $String(message.y) : message.y;
            if (message.z != null && $Object.hasOwnProperty.call(message, "z"))
                object.z = options.json && !$isFinite(message.z) ? $String(message.z) : message.z;
            if (message.rx != null && $Object.hasOwnProperty.call(message, "rx"))
                object.rx = options.json && !$isFinite(message.rx) ? $String(message.rx) : message.rx;
            if (message.ry != null && $Object.hasOwnProperty.call(message, "ry"))
                object.ry = options.json && !$isFinite(message.ry) ? $String(message.ry) : message.ry;
            if (message.rz != null && $Object.hasOwnProperty.call(message, "rz"))
                object.rz = options.json && !$isFinite(message.rz) ? $String(message.rz) : message.rz;
            if (message.rw != null && $Object.hasOwnProperty.call(message, "rw"))
                object.rw = options.json && !$isFinite(message.rw) ? $String(message.rw) : message.rw;
            if (message.animation != null && $Object.hasOwnProperty.call(message, "animation"))
                object.animation = message.animation;
            if (message.platformId != null && $Object.hasOwnProperty.call(message, "platformId"))
                object.platformId = message.platformId;
            if (message.ping != null && $Object.hasOwnProperty.call(message, "ping"))
                object.ping = message.ping;
            if (message.weaponId != null && $Object.hasOwnProperty.call(message, "weaponId"))
                object.weaponId = message.weaponId;
            return object;
        };

        /**
         * Converts this PlayerStateUpdate to JSON.
         * @function toJSON
         * @memberof warbase.PlayerStateUpdate
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        PlayerStateUpdate.prototype.toJSON = function() {
            return PlayerStateUpdate.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for PlayerStateUpdate
         * @function getTypeUrl
         * @memberof warbase.PlayerStateUpdate
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        PlayerStateUpdate.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.PlayerStateUpdate";
        };

        return PlayerStateUpdate;
    })();

    warbase.HitEvent = (function() {

        /**
         * Properties of a HitEvent.
         * @typedef {Object} warbase.HitEvent.$Properties
         * @property {string|null} [targetId] HitEvent targetId
         * @property {number|null} [damage] HitEvent damage
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a HitEvent.
         * @memberof warbase
         * @interface IHitEvent
         * @augments warbase.HitEvent.$Properties
         * @deprecated Use warbase.HitEvent.$Properties instead.
         */

        /**
         * Shape of a HitEvent.
         * @typedef {warbase.HitEvent.$Properties} warbase.HitEvent.$Shape
         */

        /**
         * Constructs a new HitEvent.
         * @memberof warbase
         * @classdesc Represents a HitEvent.
         * @constructor
         * @param {warbase.HitEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var HitEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * HitEvent targetId.
         * @member {string} targetId
         * @memberof warbase.HitEvent
         * @instance
         */
        HitEvent.prototype.targetId = "";

        /**
         * HitEvent damage.
         * @member {number} damage
         * @memberof warbase.HitEvent
         * @instance
         */
        HitEvent.prototype.damage = 0;

        /**
         * Creates a new HitEvent instance using the specified properties.
         * @function create
         * @memberof warbase.HitEvent
         * @static
         * @param {warbase.HitEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.HitEvent} HitEvent instance
         * @type {{
         *   (properties: warbase.HitEvent.$Shape): warbase.HitEvent & warbase.HitEvent.$Shape;
         *   (properties?: warbase.HitEvent.$Properties): warbase.HitEvent;
         * }}
         */
        HitEvent.create = function(properties) {
            return new HitEvent(properties);
        };

        /**
         * Encodes the specified HitEvent message. Does not implicitly {@link warbase.HitEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.HitEvent
         * @static
         * @param {warbase.HitEvent.$Properties} message HitEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        HitEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.targetId != null && $Object.hasOwnProperty.call(message, "targetId") && message.targetId !== "")
                writer.uint32(/* id 1, wireType 2 =*/10).string(message.targetId);
            if (message.damage != null && $Object.hasOwnProperty.call(message, "damage") && message.damage !== 0)
                writer.uint32(/* id 2, wireType 0 =*/16).int32(message.damage);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified HitEvent message, length delimited. Does not implicitly {@link warbase.HitEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.HitEvent
         * @static
         * @param {warbase.HitEvent.$Properties} message HitEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        HitEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a HitEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.HitEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.HitEvent & warbase.HitEvent.$Shape} HitEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        HitEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.HitEvent(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.targetId = value;
                        else
                            delete message.targetId;
                        continue;
                    }
                case 2: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.int32())
                            message.damage = value;
                        else
                            delete message.damage;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a HitEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.HitEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.HitEvent & warbase.HitEvent.$Shape} HitEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        HitEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a HitEvent message.
         * @function verify
         * @memberof warbase.HitEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        HitEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.targetId != null && $Object.hasOwnProperty.call(message, "targetId"))
                if (!$util.isString(message.targetId))
                    return "targetId: string expected";
            if (message.damage != null && $Object.hasOwnProperty.call(message, "damage"))
                if (!$util.isInteger(message.damage))
                    return "damage: integer expected";
            return null;
        };

        /**
         * Creates a HitEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.HitEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.HitEvent} HitEvent
         */
        HitEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.HitEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.HitEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.HitEvent();
            if (object.targetId != null)
                if (typeof object.targetId !== "string" || object.targetId.length)
                    message.targetId = $String(object.targetId);
            if (object.damage != null)
                if ($Number(object.damage) !== 0)
                    message.damage = object.damage | 0;
            return message;
        };

        /**
         * Creates a plain object from a HitEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.HitEvent
         * @static
         * @param {warbase.HitEvent} message HitEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        HitEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults) {
                object.targetId = "";
                object.damage = 0;
            }
            if (message.targetId != null && $Object.hasOwnProperty.call(message, "targetId"))
                object.targetId = message.targetId;
            if (message.damage != null && $Object.hasOwnProperty.call(message, "damage"))
                object.damage = message.damage;
            return object;
        };

        /**
         * Converts this HitEvent to JSON.
         * @function toJSON
         * @memberof warbase.HitEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        HitEvent.prototype.toJSON = function() {
            return HitEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for HitEvent
         * @function getTypeUrl
         * @memberof warbase.HitEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        HitEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.HitEvent";
        };

        return HitEvent;
    })();

    warbase.FireEvent = (function() {

        /**
         * Properties of a FireEvent.
         * @typedef {Object} warbase.FireEvent.$Properties
         * @property {number|null} [originX] FireEvent originX
         * @property {number|null} [originY] FireEvent originY
         * @property {number|null} [originZ] FireEvent originZ
         * @property {number|null} [hitX] FireEvent hitX
         * @property {number|null} [hitY] FireEvent hitY
         * @property {number|null} [hitZ] FireEvent hitZ
         * @property {number|null} [normalX] FireEvent normalX
         * @property {number|null} [normalY] FireEvent normalY
         * @property {number|null} [normalZ] FireEvent normalZ
         * @property {boolean|null} [hitWall] FireEvent hitWall
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a FireEvent.
         * @memberof warbase
         * @interface IFireEvent
         * @augments warbase.FireEvent.$Properties
         * @deprecated Use warbase.FireEvent.$Properties instead.
         */

        /**
         * Shape of a FireEvent.
         * @typedef {warbase.FireEvent.$Properties} warbase.FireEvent.$Shape
         */

        /**
         * Constructs a new FireEvent.
         * @memberof warbase
         * @classdesc Represents a FireEvent.
         * @constructor
         * @param {warbase.FireEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var FireEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * FireEvent originX.
         * @member {number} originX
         * @memberof warbase.FireEvent
         * @instance
         */
        FireEvent.prototype.originX = 0;

        /**
         * FireEvent originY.
         * @member {number} originY
         * @memberof warbase.FireEvent
         * @instance
         */
        FireEvent.prototype.originY = 0;

        /**
         * FireEvent originZ.
         * @member {number} originZ
         * @memberof warbase.FireEvent
         * @instance
         */
        FireEvent.prototype.originZ = 0;

        /**
         * FireEvent hitX.
         * @member {number} hitX
         * @memberof warbase.FireEvent
         * @instance
         */
        FireEvent.prototype.hitX = 0;

        /**
         * FireEvent hitY.
         * @member {number} hitY
         * @memberof warbase.FireEvent
         * @instance
         */
        FireEvent.prototype.hitY = 0;

        /**
         * FireEvent hitZ.
         * @member {number} hitZ
         * @memberof warbase.FireEvent
         * @instance
         */
        FireEvent.prototype.hitZ = 0;

        /**
         * FireEvent normalX.
         * @member {number} normalX
         * @memberof warbase.FireEvent
         * @instance
         */
        FireEvent.prototype.normalX = 0;

        /**
         * FireEvent normalY.
         * @member {number} normalY
         * @memberof warbase.FireEvent
         * @instance
         */
        FireEvent.prototype.normalY = 0;

        /**
         * FireEvent normalZ.
         * @member {number} normalZ
         * @memberof warbase.FireEvent
         * @instance
         */
        FireEvent.prototype.normalZ = 0;

        /**
         * FireEvent hitWall.
         * @member {boolean} hitWall
         * @memberof warbase.FireEvent
         * @instance
         */
        FireEvent.prototype.hitWall = false;

        /**
         * Creates a new FireEvent instance using the specified properties.
         * @function create
         * @memberof warbase.FireEvent
         * @static
         * @param {warbase.FireEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.FireEvent} FireEvent instance
         * @type {{
         *   (properties: warbase.FireEvent.$Shape): warbase.FireEvent & warbase.FireEvent.$Shape;
         *   (properties?: warbase.FireEvent.$Properties): warbase.FireEvent;
         * }}
         */
        FireEvent.create = function(properties) {
            return new FireEvent(properties);
        };

        /**
         * Encodes the specified FireEvent message. Does not implicitly {@link warbase.FireEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.FireEvent
         * @static
         * @param {warbase.FireEvent.$Properties} message FireEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        FireEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.originX != null && $Object.hasOwnProperty.call(message, "originX") && !$Object.is(message.originX, 0))
                writer.uint32(/* id 1, wireType 5 =*/13).float(message.originX);
            if (message.originY != null && $Object.hasOwnProperty.call(message, "originY") && !$Object.is(message.originY, 0))
                writer.uint32(/* id 2, wireType 5 =*/21).float(message.originY);
            if (message.originZ != null && $Object.hasOwnProperty.call(message, "originZ") && !$Object.is(message.originZ, 0))
                writer.uint32(/* id 3, wireType 5 =*/29).float(message.originZ);
            if (message.hitX != null && $Object.hasOwnProperty.call(message, "hitX") && !$Object.is(message.hitX, 0))
                writer.uint32(/* id 4, wireType 5 =*/37).float(message.hitX);
            if (message.hitY != null && $Object.hasOwnProperty.call(message, "hitY") && !$Object.is(message.hitY, 0))
                writer.uint32(/* id 5, wireType 5 =*/45).float(message.hitY);
            if (message.hitZ != null && $Object.hasOwnProperty.call(message, "hitZ") && !$Object.is(message.hitZ, 0))
                writer.uint32(/* id 6, wireType 5 =*/53).float(message.hitZ);
            if (message.normalX != null && $Object.hasOwnProperty.call(message, "normalX") && !$Object.is(message.normalX, 0))
                writer.uint32(/* id 7, wireType 5 =*/61).float(message.normalX);
            if (message.normalY != null && $Object.hasOwnProperty.call(message, "normalY") && !$Object.is(message.normalY, 0))
                writer.uint32(/* id 8, wireType 5 =*/69).float(message.normalY);
            if (message.normalZ != null && $Object.hasOwnProperty.call(message, "normalZ") && !$Object.is(message.normalZ, 0))
                writer.uint32(/* id 9, wireType 5 =*/77).float(message.normalZ);
            if (message.hitWall != null && $Object.hasOwnProperty.call(message, "hitWall") && message.hitWall !== false)
                writer.uint32(/* id 10, wireType 0 =*/80).bool(message.hitWall);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified FireEvent message, length delimited. Does not implicitly {@link warbase.FireEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.FireEvent
         * @static
         * @param {warbase.FireEvent.$Properties} message FireEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        FireEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a FireEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.FireEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.FireEvent & warbase.FireEvent.$Shape} FireEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        FireEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.FireEvent(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.originX = value;
                        else
                            delete message.originX;
                        continue;
                    }
                case 2: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.originY = value;
                        else
                            delete message.originY;
                        continue;
                    }
                case 3: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.originZ = value;
                        else
                            delete message.originZ;
                        continue;
                    }
                case 4: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.hitX = value;
                        else
                            delete message.hitX;
                        continue;
                    }
                case 5: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.hitY = value;
                        else
                            delete message.hitY;
                        continue;
                    }
                case 6: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.hitZ = value;
                        else
                            delete message.hitZ;
                        continue;
                    }
                case 7: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.normalX = value;
                        else
                            delete message.normalX;
                        continue;
                    }
                case 8: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.normalY = value;
                        else
                            delete message.normalY;
                        continue;
                    }
                case 9: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.normalZ = value;
                        else
                            delete message.normalZ;
                        continue;
                    }
                case 10: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.bool())
                            message.hitWall = value;
                        else
                            delete message.hitWall;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a FireEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.FireEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.FireEvent & warbase.FireEvent.$Shape} FireEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        FireEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a FireEvent message.
         * @function verify
         * @memberof warbase.FireEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        FireEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.originX != null && $Object.hasOwnProperty.call(message, "originX"))
                if (typeof message.originX !== "number")
                    return "originX: number expected";
            if (message.originY != null && $Object.hasOwnProperty.call(message, "originY"))
                if (typeof message.originY !== "number")
                    return "originY: number expected";
            if (message.originZ != null && $Object.hasOwnProperty.call(message, "originZ"))
                if (typeof message.originZ !== "number")
                    return "originZ: number expected";
            if (message.hitX != null && $Object.hasOwnProperty.call(message, "hitX"))
                if (typeof message.hitX !== "number")
                    return "hitX: number expected";
            if (message.hitY != null && $Object.hasOwnProperty.call(message, "hitY"))
                if (typeof message.hitY !== "number")
                    return "hitY: number expected";
            if (message.hitZ != null && $Object.hasOwnProperty.call(message, "hitZ"))
                if (typeof message.hitZ !== "number")
                    return "hitZ: number expected";
            if (message.normalX != null && $Object.hasOwnProperty.call(message, "normalX"))
                if (typeof message.normalX !== "number")
                    return "normalX: number expected";
            if (message.normalY != null && $Object.hasOwnProperty.call(message, "normalY"))
                if (typeof message.normalY !== "number")
                    return "normalY: number expected";
            if (message.normalZ != null && $Object.hasOwnProperty.call(message, "normalZ"))
                if (typeof message.normalZ !== "number")
                    return "normalZ: number expected";
            if (message.hitWall != null && $Object.hasOwnProperty.call(message, "hitWall"))
                if (typeof message.hitWall !== "boolean")
                    return "hitWall: boolean expected";
            return null;
        };

        /**
         * Creates a FireEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.FireEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.FireEvent} FireEvent
         */
        FireEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.FireEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.FireEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.FireEvent();
            if (object.originX != null)
                if (!$Object.is($Number(object.originX), 0))
                    message.originX = $Number(object.originX);
            if (object.originY != null)
                if (!$Object.is($Number(object.originY), 0))
                    message.originY = $Number(object.originY);
            if (object.originZ != null)
                if (!$Object.is($Number(object.originZ), 0))
                    message.originZ = $Number(object.originZ);
            if (object.hitX != null)
                if (!$Object.is($Number(object.hitX), 0))
                    message.hitX = $Number(object.hitX);
            if (object.hitY != null)
                if (!$Object.is($Number(object.hitY), 0))
                    message.hitY = $Number(object.hitY);
            if (object.hitZ != null)
                if (!$Object.is($Number(object.hitZ), 0))
                    message.hitZ = $Number(object.hitZ);
            if (object.normalX != null)
                if (!$Object.is($Number(object.normalX), 0))
                    message.normalX = $Number(object.normalX);
            if (object.normalY != null)
                if (!$Object.is($Number(object.normalY), 0))
                    message.normalY = $Number(object.normalY);
            if (object.normalZ != null)
                if (!$Object.is($Number(object.normalZ), 0))
                    message.normalZ = $Number(object.normalZ);
            if (object.hitWall != null)
                if (object.hitWall)
                    message.hitWall = $Boolean(object.hitWall);
            return message;
        };

        /**
         * Creates a plain object from a FireEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.FireEvent
         * @static
         * @param {warbase.FireEvent} message FireEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        FireEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults) {
                object.originX = 0;
                object.originY = 0;
                object.originZ = 0;
                object.hitX = 0;
                object.hitY = 0;
                object.hitZ = 0;
                object.normalX = 0;
                object.normalY = 0;
                object.normalZ = 0;
                object.hitWall = false;
            }
            if (message.originX != null && $Object.hasOwnProperty.call(message, "originX"))
                object.originX = options.json && !$isFinite(message.originX) ? $String(message.originX) : message.originX;
            if (message.originY != null && $Object.hasOwnProperty.call(message, "originY"))
                object.originY = options.json && !$isFinite(message.originY) ? $String(message.originY) : message.originY;
            if (message.originZ != null && $Object.hasOwnProperty.call(message, "originZ"))
                object.originZ = options.json && !$isFinite(message.originZ) ? $String(message.originZ) : message.originZ;
            if (message.hitX != null && $Object.hasOwnProperty.call(message, "hitX"))
                object.hitX = options.json && !$isFinite(message.hitX) ? $String(message.hitX) : message.hitX;
            if (message.hitY != null && $Object.hasOwnProperty.call(message, "hitY"))
                object.hitY = options.json && !$isFinite(message.hitY) ? $String(message.hitY) : message.hitY;
            if (message.hitZ != null && $Object.hasOwnProperty.call(message, "hitZ"))
                object.hitZ = options.json && !$isFinite(message.hitZ) ? $String(message.hitZ) : message.hitZ;
            if (message.normalX != null && $Object.hasOwnProperty.call(message, "normalX"))
                object.normalX = options.json && !$isFinite(message.normalX) ? $String(message.normalX) : message.normalX;
            if (message.normalY != null && $Object.hasOwnProperty.call(message, "normalY"))
                object.normalY = options.json && !$isFinite(message.normalY) ? $String(message.normalY) : message.normalY;
            if (message.normalZ != null && $Object.hasOwnProperty.call(message, "normalZ"))
                object.normalZ = options.json && !$isFinite(message.normalZ) ? $String(message.normalZ) : message.normalZ;
            if (message.hitWall != null && $Object.hasOwnProperty.call(message, "hitWall"))
                object.hitWall = message.hitWall;
            return object;
        };

        /**
         * Converts this FireEvent to JSON.
         * @function toJSON
         * @memberof warbase.FireEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        FireEvent.prototype.toJSON = function() {
            return FireEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for FireEvent
         * @function getTypeUrl
         * @memberof warbase.FireEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        FireEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.FireEvent";
        };

        return FireEvent;
    })();

    warbase.ReloadEvent = (function() {

        /**
         * Properties of a ReloadEvent.
         * @typedef {Object} warbase.ReloadEvent.$Properties
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a ReloadEvent.
         * @memberof warbase
         * @interface IReloadEvent
         * @augments warbase.ReloadEvent.$Properties
         * @deprecated Use warbase.ReloadEvent.$Properties instead.
         */

        /**
         * Shape of a ReloadEvent.
         * @typedef {warbase.ReloadEvent.$Properties} warbase.ReloadEvent.$Shape
         */

        /**
         * Constructs a new ReloadEvent.
         * @memberof warbase
         * @classdesc Represents a ReloadEvent.
         * @constructor
         * @param {warbase.ReloadEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var ReloadEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * Creates a new ReloadEvent instance using the specified properties.
         * @function create
         * @memberof warbase.ReloadEvent
         * @static
         * @param {warbase.ReloadEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.ReloadEvent} ReloadEvent instance
         * @type {{
         *   (properties: warbase.ReloadEvent.$Shape): warbase.ReloadEvent & warbase.ReloadEvent.$Shape;
         *   (properties?: warbase.ReloadEvent.$Properties): warbase.ReloadEvent;
         * }}
         */
        ReloadEvent.create = function(properties) {
            return new ReloadEvent(properties);
        };

        /**
         * Encodes the specified ReloadEvent message. Does not implicitly {@link warbase.ReloadEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.ReloadEvent
         * @static
         * @param {warbase.ReloadEvent.$Properties} message ReloadEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ReloadEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified ReloadEvent message, length delimited. Does not implicitly {@link warbase.ReloadEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.ReloadEvent
         * @static
         * @param {warbase.ReloadEvent.$Properties} message ReloadEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ReloadEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a ReloadEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.ReloadEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.ReloadEvent & warbase.ReloadEvent.$Shape} ReloadEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ReloadEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.ReloadEvent();
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                reader.skipType(tag & 7, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a ReloadEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.ReloadEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.ReloadEvent & warbase.ReloadEvent.$Shape} ReloadEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ReloadEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a ReloadEvent message.
         * @function verify
         * @memberof warbase.ReloadEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        ReloadEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            return null;
        };

        /**
         * Creates a ReloadEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.ReloadEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.ReloadEvent} ReloadEvent
         */
        ReloadEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.ReloadEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.ReloadEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            return new $root.warbase.ReloadEvent();
        };

        /**
         * Creates a plain object from a ReloadEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.ReloadEvent
         * @static
         * @param {warbase.ReloadEvent} message ReloadEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        ReloadEvent.toObject = function () {
            return {};
        };

        /**
         * Converts this ReloadEvent to JSON.
         * @function toJSON
         * @memberof warbase.ReloadEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        ReloadEvent.prototype.toJSON = function() {
            return ReloadEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for ReloadEvent
         * @function getTypeUrl
         * @memberof warbase.ReloadEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        ReloadEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.ReloadEvent";
        };

        return ReloadEvent;
    })();

    warbase.SwitchWeaponEvent = (function() {

        /**
         * Properties of a SwitchWeaponEvent.
         * @typedef {Object} warbase.SwitchWeaponEvent.$Properties
         * @property {string|null} [weaponId] SwitchWeaponEvent weaponId
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a SwitchWeaponEvent.
         * @memberof warbase
         * @interface ISwitchWeaponEvent
         * @augments warbase.SwitchWeaponEvent.$Properties
         * @deprecated Use warbase.SwitchWeaponEvent.$Properties instead.
         */

        /**
         * Shape of a SwitchWeaponEvent.
         * @typedef {warbase.SwitchWeaponEvent.$Properties} warbase.SwitchWeaponEvent.$Shape
         */

        /**
         * Constructs a new SwitchWeaponEvent.
         * @memberof warbase
         * @classdesc Represents a SwitchWeaponEvent.
         * @constructor
         * @param {warbase.SwitchWeaponEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var SwitchWeaponEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * SwitchWeaponEvent weaponId.
         * @member {string} weaponId
         * @memberof warbase.SwitchWeaponEvent
         * @instance
         */
        SwitchWeaponEvent.prototype.weaponId = "";

        /**
         * Creates a new SwitchWeaponEvent instance using the specified properties.
         * @function create
         * @memberof warbase.SwitchWeaponEvent
         * @static
         * @param {warbase.SwitchWeaponEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.SwitchWeaponEvent} SwitchWeaponEvent instance
         * @type {{
         *   (properties: warbase.SwitchWeaponEvent.$Shape): warbase.SwitchWeaponEvent & warbase.SwitchWeaponEvent.$Shape;
         *   (properties?: warbase.SwitchWeaponEvent.$Properties): warbase.SwitchWeaponEvent;
         * }}
         */
        SwitchWeaponEvent.create = function(properties) {
            return new SwitchWeaponEvent(properties);
        };

        /**
         * Encodes the specified SwitchWeaponEvent message. Does not implicitly {@link warbase.SwitchWeaponEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.SwitchWeaponEvent
         * @static
         * @param {warbase.SwitchWeaponEvent.$Properties} message SwitchWeaponEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        SwitchWeaponEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.weaponId != null && $Object.hasOwnProperty.call(message, "weaponId") && message.weaponId !== "")
                writer.uint32(/* id 1, wireType 2 =*/10).string(message.weaponId);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified SwitchWeaponEvent message, length delimited. Does not implicitly {@link warbase.SwitchWeaponEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.SwitchWeaponEvent
         * @static
         * @param {warbase.SwitchWeaponEvent.$Properties} message SwitchWeaponEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        SwitchWeaponEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a SwitchWeaponEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.SwitchWeaponEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.SwitchWeaponEvent & warbase.SwitchWeaponEvent.$Shape} SwitchWeaponEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        SwitchWeaponEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.SwitchWeaponEvent(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.weaponId = value;
                        else
                            delete message.weaponId;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a SwitchWeaponEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.SwitchWeaponEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.SwitchWeaponEvent & warbase.SwitchWeaponEvent.$Shape} SwitchWeaponEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        SwitchWeaponEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a SwitchWeaponEvent message.
         * @function verify
         * @memberof warbase.SwitchWeaponEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        SwitchWeaponEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.weaponId != null && $Object.hasOwnProperty.call(message, "weaponId"))
                if (!$util.isString(message.weaponId))
                    return "weaponId: string expected";
            return null;
        };

        /**
         * Creates a SwitchWeaponEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.SwitchWeaponEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.SwitchWeaponEvent} SwitchWeaponEvent
         */
        SwitchWeaponEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.SwitchWeaponEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.SwitchWeaponEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.SwitchWeaponEvent();
            if (object.weaponId != null)
                if (typeof object.weaponId !== "string" || object.weaponId.length)
                    message.weaponId = $String(object.weaponId);
            return message;
        };

        /**
         * Creates a plain object from a SwitchWeaponEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.SwitchWeaponEvent
         * @static
         * @param {warbase.SwitchWeaponEvent} message SwitchWeaponEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        SwitchWeaponEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults)
                object.weaponId = "";
            if (message.weaponId != null && $Object.hasOwnProperty.call(message, "weaponId"))
                object.weaponId = message.weaponId;
            return object;
        };

        /**
         * Converts this SwitchWeaponEvent to JSON.
         * @function toJSON
         * @memberof warbase.SwitchWeaponEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        SwitchWeaponEvent.prototype.toJSON = function() {
            return SwitchWeaponEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for SwitchWeaponEvent
         * @function getTypeUrl
         * @memberof warbase.SwitchWeaponEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        SwitchWeaponEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.SwitchWeaponEvent";
        };

        return SwitchWeaponEvent;
    })();

    warbase.RespawnRequestEvent = (function() {

        /**
         * Properties of a RespawnRequestEvent.
         * @typedef {Object} warbase.RespawnRequestEvent.$Properties
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a RespawnRequestEvent.
         * @memberof warbase
         * @interface IRespawnRequestEvent
         * @augments warbase.RespawnRequestEvent.$Properties
         * @deprecated Use warbase.RespawnRequestEvent.$Properties instead.
         */

        /**
         * Shape of a RespawnRequestEvent.
         * @typedef {warbase.RespawnRequestEvent.$Properties} warbase.RespawnRequestEvent.$Shape
         */

        /**
         * Constructs a new RespawnRequestEvent.
         * @memberof warbase
         * @classdesc Represents a RespawnRequestEvent.
         * @constructor
         * @param {warbase.RespawnRequestEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var RespawnRequestEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * Creates a new RespawnRequestEvent instance using the specified properties.
         * @function create
         * @memberof warbase.RespawnRequestEvent
         * @static
         * @param {warbase.RespawnRequestEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.RespawnRequestEvent} RespawnRequestEvent instance
         * @type {{
         *   (properties: warbase.RespawnRequestEvent.$Shape): warbase.RespawnRequestEvent & warbase.RespawnRequestEvent.$Shape;
         *   (properties?: warbase.RespawnRequestEvent.$Properties): warbase.RespawnRequestEvent;
         * }}
         */
        RespawnRequestEvent.create = function(properties) {
            return new RespawnRequestEvent(properties);
        };

        /**
         * Encodes the specified RespawnRequestEvent message. Does not implicitly {@link warbase.RespawnRequestEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.RespawnRequestEvent
         * @static
         * @param {warbase.RespawnRequestEvent.$Properties} message RespawnRequestEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        RespawnRequestEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified RespawnRequestEvent message, length delimited. Does not implicitly {@link warbase.RespawnRequestEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.RespawnRequestEvent
         * @static
         * @param {warbase.RespawnRequestEvent.$Properties} message RespawnRequestEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        RespawnRequestEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a RespawnRequestEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.RespawnRequestEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.RespawnRequestEvent & warbase.RespawnRequestEvent.$Shape} RespawnRequestEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        RespawnRequestEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.RespawnRequestEvent();
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                reader.skipType(tag & 7, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a RespawnRequestEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.RespawnRequestEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.RespawnRequestEvent & warbase.RespawnRequestEvent.$Shape} RespawnRequestEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        RespawnRequestEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a RespawnRequestEvent message.
         * @function verify
         * @memberof warbase.RespawnRequestEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        RespawnRequestEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            return null;
        };

        /**
         * Creates a RespawnRequestEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.RespawnRequestEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.RespawnRequestEvent} RespawnRequestEvent
         */
        RespawnRequestEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.RespawnRequestEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.RespawnRequestEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            return new $root.warbase.RespawnRequestEvent();
        };

        /**
         * Creates a plain object from a RespawnRequestEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.RespawnRequestEvent
         * @static
         * @param {warbase.RespawnRequestEvent} message RespawnRequestEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        RespawnRequestEvent.toObject = function () {
            return {};
        };

        /**
         * Converts this RespawnRequestEvent to JSON.
         * @function toJSON
         * @memberof warbase.RespawnRequestEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        RespawnRequestEvent.prototype.toJSON = function() {
            return RespawnRequestEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for RespawnRequestEvent
         * @function getTypeUrl
         * @memberof warbase.RespawnRequestEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        RespawnRequestEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.RespawnRequestEvent";
        };

        return RespawnRequestEvent;
    })();

    warbase.ThrowGrenadeEvent = (function() {

        /**
         * Properties of a ThrowGrenadeEvent.
         * @typedef {Object} warbase.ThrowGrenadeEvent.$Properties
         * @property {number|null} [px] ThrowGrenadeEvent px
         * @property {number|null} [py] ThrowGrenadeEvent py
         * @property {number|null} [pz] ThrowGrenadeEvent pz
         * @property {number|null} [vx] ThrowGrenadeEvent vx
         * @property {number|null} [vy] ThrowGrenadeEvent vy
         * @property {number|null} [vz] ThrowGrenadeEvent vz
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a ThrowGrenadeEvent.
         * @memberof warbase
         * @interface IThrowGrenadeEvent
         * @augments warbase.ThrowGrenadeEvent.$Properties
         * @deprecated Use warbase.ThrowGrenadeEvent.$Properties instead.
         */

        /**
         * Shape of a ThrowGrenadeEvent.
         * @typedef {warbase.ThrowGrenadeEvent.$Properties} warbase.ThrowGrenadeEvent.$Shape
         */

        /**
         * Constructs a new ThrowGrenadeEvent.
         * @memberof warbase
         * @classdesc Represents a ThrowGrenadeEvent.
         * @constructor
         * @param {warbase.ThrowGrenadeEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var ThrowGrenadeEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * ThrowGrenadeEvent px.
         * @member {number} px
         * @memberof warbase.ThrowGrenadeEvent
         * @instance
         */
        ThrowGrenadeEvent.prototype.px = 0;

        /**
         * ThrowGrenadeEvent py.
         * @member {number} py
         * @memberof warbase.ThrowGrenadeEvent
         * @instance
         */
        ThrowGrenadeEvent.prototype.py = 0;

        /**
         * ThrowGrenadeEvent pz.
         * @member {number} pz
         * @memberof warbase.ThrowGrenadeEvent
         * @instance
         */
        ThrowGrenadeEvent.prototype.pz = 0;

        /**
         * ThrowGrenadeEvent vx.
         * @member {number} vx
         * @memberof warbase.ThrowGrenadeEvent
         * @instance
         */
        ThrowGrenadeEvent.prototype.vx = 0;

        /**
         * ThrowGrenadeEvent vy.
         * @member {number} vy
         * @memberof warbase.ThrowGrenadeEvent
         * @instance
         */
        ThrowGrenadeEvent.prototype.vy = 0;

        /**
         * ThrowGrenadeEvent vz.
         * @member {number} vz
         * @memberof warbase.ThrowGrenadeEvent
         * @instance
         */
        ThrowGrenadeEvent.prototype.vz = 0;

        /**
         * Creates a new ThrowGrenadeEvent instance using the specified properties.
         * @function create
         * @memberof warbase.ThrowGrenadeEvent
         * @static
         * @param {warbase.ThrowGrenadeEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.ThrowGrenadeEvent} ThrowGrenadeEvent instance
         * @type {{
         *   (properties: warbase.ThrowGrenadeEvent.$Shape): warbase.ThrowGrenadeEvent & warbase.ThrowGrenadeEvent.$Shape;
         *   (properties?: warbase.ThrowGrenadeEvent.$Properties): warbase.ThrowGrenadeEvent;
         * }}
         */
        ThrowGrenadeEvent.create = function(properties) {
            return new ThrowGrenadeEvent(properties);
        };

        /**
         * Encodes the specified ThrowGrenadeEvent message. Does not implicitly {@link warbase.ThrowGrenadeEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.ThrowGrenadeEvent
         * @static
         * @param {warbase.ThrowGrenadeEvent.$Properties} message ThrowGrenadeEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ThrowGrenadeEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.px != null && $Object.hasOwnProperty.call(message, "px") && !$Object.is(message.px, 0))
                writer.uint32(/* id 1, wireType 5 =*/13).float(message.px);
            if (message.py != null && $Object.hasOwnProperty.call(message, "py") && !$Object.is(message.py, 0))
                writer.uint32(/* id 2, wireType 5 =*/21).float(message.py);
            if (message.pz != null && $Object.hasOwnProperty.call(message, "pz") && !$Object.is(message.pz, 0))
                writer.uint32(/* id 3, wireType 5 =*/29).float(message.pz);
            if (message.vx != null && $Object.hasOwnProperty.call(message, "vx") && !$Object.is(message.vx, 0))
                writer.uint32(/* id 4, wireType 5 =*/37).float(message.vx);
            if (message.vy != null && $Object.hasOwnProperty.call(message, "vy") && !$Object.is(message.vy, 0))
                writer.uint32(/* id 5, wireType 5 =*/45).float(message.vy);
            if (message.vz != null && $Object.hasOwnProperty.call(message, "vz") && !$Object.is(message.vz, 0))
                writer.uint32(/* id 6, wireType 5 =*/53).float(message.vz);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified ThrowGrenadeEvent message, length delimited. Does not implicitly {@link warbase.ThrowGrenadeEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.ThrowGrenadeEvent
         * @static
         * @param {warbase.ThrowGrenadeEvent.$Properties} message ThrowGrenadeEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ThrowGrenadeEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a ThrowGrenadeEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.ThrowGrenadeEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.ThrowGrenadeEvent & warbase.ThrowGrenadeEvent.$Shape} ThrowGrenadeEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ThrowGrenadeEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.ThrowGrenadeEvent(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.px = value;
                        else
                            delete message.px;
                        continue;
                    }
                case 2: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.py = value;
                        else
                            delete message.py;
                        continue;
                    }
                case 3: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.pz = value;
                        else
                            delete message.pz;
                        continue;
                    }
                case 4: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.vx = value;
                        else
                            delete message.vx;
                        continue;
                    }
                case 5: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.vy = value;
                        else
                            delete message.vy;
                        continue;
                    }
                case 6: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.vz = value;
                        else
                            delete message.vz;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a ThrowGrenadeEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.ThrowGrenadeEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.ThrowGrenadeEvent & warbase.ThrowGrenadeEvent.$Shape} ThrowGrenadeEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ThrowGrenadeEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a ThrowGrenadeEvent message.
         * @function verify
         * @memberof warbase.ThrowGrenadeEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        ThrowGrenadeEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.px != null && $Object.hasOwnProperty.call(message, "px"))
                if (typeof message.px !== "number")
                    return "px: number expected";
            if (message.py != null && $Object.hasOwnProperty.call(message, "py"))
                if (typeof message.py !== "number")
                    return "py: number expected";
            if (message.pz != null && $Object.hasOwnProperty.call(message, "pz"))
                if (typeof message.pz !== "number")
                    return "pz: number expected";
            if (message.vx != null && $Object.hasOwnProperty.call(message, "vx"))
                if (typeof message.vx !== "number")
                    return "vx: number expected";
            if (message.vy != null && $Object.hasOwnProperty.call(message, "vy"))
                if (typeof message.vy !== "number")
                    return "vy: number expected";
            if (message.vz != null && $Object.hasOwnProperty.call(message, "vz"))
                if (typeof message.vz !== "number")
                    return "vz: number expected";
            return null;
        };

        /**
         * Creates a ThrowGrenadeEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.ThrowGrenadeEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.ThrowGrenadeEvent} ThrowGrenadeEvent
         */
        ThrowGrenadeEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.ThrowGrenadeEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.ThrowGrenadeEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.ThrowGrenadeEvent();
            if (object.px != null)
                if (!$Object.is($Number(object.px), 0))
                    message.px = $Number(object.px);
            if (object.py != null)
                if (!$Object.is($Number(object.py), 0))
                    message.py = $Number(object.py);
            if (object.pz != null)
                if (!$Object.is($Number(object.pz), 0))
                    message.pz = $Number(object.pz);
            if (object.vx != null)
                if (!$Object.is($Number(object.vx), 0))
                    message.vx = $Number(object.vx);
            if (object.vy != null)
                if (!$Object.is($Number(object.vy), 0))
                    message.vy = $Number(object.vy);
            if (object.vz != null)
                if (!$Object.is($Number(object.vz), 0))
                    message.vz = $Number(object.vz);
            return message;
        };

        /**
         * Creates a plain object from a ThrowGrenadeEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.ThrowGrenadeEvent
         * @static
         * @param {warbase.ThrowGrenadeEvent} message ThrowGrenadeEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        ThrowGrenadeEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults) {
                object.px = 0;
                object.py = 0;
                object.pz = 0;
                object.vx = 0;
                object.vy = 0;
                object.vz = 0;
            }
            if (message.px != null && $Object.hasOwnProperty.call(message, "px"))
                object.px = options.json && !$isFinite(message.px) ? $String(message.px) : message.px;
            if (message.py != null && $Object.hasOwnProperty.call(message, "py"))
                object.py = options.json && !$isFinite(message.py) ? $String(message.py) : message.py;
            if (message.pz != null && $Object.hasOwnProperty.call(message, "pz"))
                object.pz = options.json && !$isFinite(message.pz) ? $String(message.pz) : message.pz;
            if (message.vx != null && $Object.hasOwnProperty.call(message, "vx"))
                object.vx = options.json && !$isFinite(message.vx) ? $String(message.vx) : message.vx;
            if (message.vy != null && $Object.hasOwnProperty.call(message, "vy"))
                object.vy = options.json && !$isFinite(message.vy) ? $String(message.vy) : message.vy;
            if (message.vz != null && $Object.hasOwnProperty.call(message, "vz"))
                object.vz = options.json && !$isFinite(message.vz) ? $String(message.vz) : message.vz;
            return object;
        };

        /**
         * Converts this ThrowGrenadeEvent to JSON.
         * @function toJSON
         * @memberof warbase.ThrowGrenadeEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        ThrowGrenadeEvent.prototype.toJSON = function() {
            return ThrowGrenadeEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for ThrowGrenadeEvent
         * @function getTypeUrl
         * @memberof warbase.ThrowGrenadeEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        ThrowGrenadeEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.ThrowGrenadeEvent";
        };

        return ThrowGrenadeEvent;
    })();

    warbase.ServerPongEvent = (function() {

        /**
         * Properties of a ServerPongEvent.
         * @typedef {Object} warbase.ServerPongEvent.$Properties
         * @property {number|Long|null} [clientTime] ServerPongEvent clientTime
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a ServerPongEvent.
         * @memberof warbase
         * @interface IServerPongEvent
         * @augments warbase.ServerPongEvent.$Properties
         * @deprecated Use warbase.ServerPongEvent.$Properties instead.
         */

        /**
         * Shape of a ServerPongEvent.
         * @typedef {warbase.ServerPongEvent.$Properties} warbase.ServerPongEvent.$Shape
         */

        /**
         * Constructs a new ServerPongEvent.
         * @memberof warbase
         * @classdesc Represents a ServerPongEvent.
         * @constructor
         * @param {warbase.ServerPongEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var ServerPongEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * ServerPongEvent clientTime.
         * @member {number|Long} clientTime
         * @memberof warbase.ServerPongEvent
         * @instance
         */
        ServerPongEvent.prototype.clientTime = $util.Long ? $util.Long.fromBits(0,0,false) : 0;

        /**
         * Creates a new ServerPongEvent instance using the specified properties.
         * @function create
         * @memberof warbase.ServerPongEvent
         * @static
         * @param {warbase.ServerPongEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.ServerPongEvent} ServerPongEvent instance
         * @type {{
         *   (properties: warbase.ServerPongEvent.$Shape): warbase.ServerPongEvent & warbase.ServerPongEvent.$Shape;
         *   (properties?: warbase.ServerPongEvent.$Properties): warbase.ServerPongEvent;
         * }}
         */
        ServerPongEvent.create = function(properties) {
            return new ServerPongEvent(properties);
        };

        /**
         * Encodes the specified ServerPongEvent message. Does not implicitly {@link warbase.ServerPongEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.ServerPongEvent
         * @static
         * @param {warbase.ServerPongEvent.$Properties} message ServerPongEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ServerPongEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.clientTime != null && $Object.hasOwnProperty.call(message, "clientTime") && (typeof message.clientTime === "object" ? message.clientTime.low || message.clientTime.high : message.clientTime !== 0))
                writer.uint32(/* id 1, wireType 0 =*/8).int64(message.clientTime);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified ServerPongEvent message, length delimited. Does not implicitly {@link warbase.ServerPongEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.ServerPongEvent
         * @static
         * @param {warbase.ServerPongEvent.$Properties} message ServerPongEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ServerPongEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a ServerPongEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.ServerPongEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.ServerPongEvent & warbase.ServerPongEvent.$Shape} ServerPongEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ServerPongEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.ServerPongEvent(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 0)
                            break;
                        if (typeof (value = reader.int64()) === "object" ? value.low || value.high : value !== 0)
                            message.clientTime = value;
                        else
                            delete message.clientTime;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a ServerPongEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.ServerPongEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.ServerPongEvent & warbase.ServerPongEvent.$Shape} ServerPongEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ServerPongEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a ServerPongEvent message.
         * @function verify
         * @memberof warbase.ServerPongEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        ServerPongEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.clientTime != null && $Object.hasOwnProperty.call(message, "clientTime"))
                if (!$util.isInteger(message.clientTime) && !(message.clientTime && $util.isInteger(message.clientTime.low) && $util.isInteger(message.clientTime.high)))
                    return "clientTime: integer|Long expected";
            return null;
        };

        /**
         * Creates a ServerPongEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.ServerPongEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.ServerPongEvent} ServerPongEvent
         */
        ServerPongEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.ServerPongEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.ServerPongEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.ServerPongEvent();
            if (object.clientTime != null)
                if (typeof object.clientTime === "object" ? object.clientTime.low || object.clientTime.high : $Number(object.clientTime) !== 0)
                    if ($util.Long)
                        message.clientTime = $util.Long.fromValue(object.clientTime, false);
                    else if (typeof object.clientTime === "string")
                        message.clientTime = $parseInt(object.clientTime, 10);
                    else if (typeof object.clientTime === "number")
                        message.clientTime = object.clientTime;
                    else if (typeof object.clientTime === "object")
                        message.clientTime = new $util.LongBits(object.clientTime.low >>> 0, object.clientTime.high >>> 0).toNumber();
            return message;
        };

        /**
         * Creates a plain object from a ServerPongEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.ServerPongEvent
         * @static
         * @param {warbase.ServerPongEvent} message ServerPongEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        ServerPongEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults)
                if ($util.Long) {
                    var long = new $util.Long(0, 0, false);
                    object.clientTime = options.longs === $String ? long.toString() : options.longs === $Number ? long.toNumber() : typeof $BigInt !== "undefined" && options.longs === $BigInt ? long.toBigInt() : long;
                } else
                    object.clientTime = options.longs === $String ? "0" : typeof $BigInt !== "undefined" && options.longs === $BigInt ? $BigInt("0") : 0;
            if (message.clientTime != null && $Object.hasOwnProperty.call(message, "clientTime"))
                if (typeof $BigInt !== "undefined" && options.longs === $BigInt)
                    object.clientTime = typeof message.clientTime === "number" ? $BigInt(message.clientTime) : $util.Long.fromBits(message.clientTime.low >>> 0, message.clientTime.high >>> 0, false).toBigInt();
                else if (typeof message.clientTime === "number")
                    object.clientTime = options.longs === $String ? $String(message.clientTime) : message.clientTime;
                else
                    object.clientTime = options.longs === $String ? $util.Long.prototype.toString.call(message.clientTime) : options.longs === $Number ? new $util.LongBits(message.clientTime.low >>> 0, message.clientTime.high >>> 0).toNumber() : message.clientTime;
            return object;
        };

        /**
         * Converts this ServerPongEvent to JSON.
         * @function toJSON
         * @memberof warbase.ServerPongEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        ServerPongEvent.prototype.toJSON = function() {
            return ServerPongEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for ServerPongEvent
         * @function getTypeUrl
         * @memberof warbase.ServerPongEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        ServerPongEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.ServerPongEvent";
        };

        return ServerPongEvent;
    })();

    warbase.PingEvent = (function() {

        /**
         * Properties of a PingEvent.
         * @typedef {Object} warbase.PingEvent.$Properties
         * @property {number|Long|null} [clientTime] PingEvent clientTime
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a PingEvent.
         * @memberof warbase
         * @interface IPingEvent
         * @augments warbase.PingEvent.$Properties
         * @deprecated Use warbase.PingEvent.$Properties instead.
         */

        /**
         * Shape of a PingEvent.
         * @typedef {warbase.PingEvent.$Properties} warbase.PingEvent.$Shape
         */

        /**
         * Constructs a new PingEvent.
         * @memberof warbase
         * @classdesc Represents a PingEvent.
         * @constructor
         * @param {warbase.PingEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var PingEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * PingEvent clientTime.
         * @member {number|Long} clientTime
         * @memberof warbase.PingEvent
         * @instance
         */
        PingEvent.prototype.clientTime = $util.Long ? $util.Long.fromBits(0,0,false) : 0;

        /**
         * Creates a new PingEvent instance using the specified properties.
         * @function create
         * @memberof warbase.PingEvent
         * @static
         * @param {warbase.PingEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.PingEvent} PingEvent instance
         * @type {{
         *   (properties: warbase.PingEvent.$Shape): warbase.PingEvent & warbase.PingEvent.$Shape;
         *   (properties?: warbase.PingEvent.$Properties): warbase.PingEvent;
         * }}
         */
        PingEvent.create = function(properties) {
            return new PingEvent(properties);
        };

        /**
         * Encodes the specified PingEvent message. Does not implicitly {@link warbase.PingEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.PingEvent
         * @static
         * @param {warbase.PingEvent.$Properties} message PingEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        PingEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.clientTime != null && $Object.hasOwnProperty.call(message, "clientTime") && (typeof message.clientTime === "object" ? message.clientTime.low || message.clientTime.high : message.clientTime !== 0))
                writer.uint32(/* id 1, wireType 0 =*/8).int64(message.clientTime);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified PingEvent message, length delimited. Does not implicitly {@link warbase.PingEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.PingEvent
         * @static
         * @param {warbase.PingEvent.$Properties} message PingEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        PingEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a PingEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.PingEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.PingEvent & warbase.PingEvent.$Shape} PingEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        PingEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.PingEvent(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 0)
                            break;
                        if (typeof (value = reader.int64()) === "object" ? value.low || value.high : value !== 0)
                            message.clientTime = value;
                        else
                            delete message.clientTime;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a PingEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.PingEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.PingEvent & warbase.PingEvent.$Shape} PingEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        PingEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a PingEvent message.
         * @function verify
         * @memberof warbase.PingEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        PingEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.clientTime != null && $Object.hasOwnProperty.call(message, "clientTime"))
                if (!$util.isInteger(message.clientTime) && !(message.clientTime && $util.isInteger(message.clientTime.low) && $util.isInteger(message.clientTime.high)))
                    return "clientTime: integer|Long expected";
            return null;
        };

        /**
         * Creates a PingEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.PingEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.PingEvent} PingEvent
         */
        PingEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.PingEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.PingEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.PingEvent();
            if (object.clientTime != null)
                if (typeof object.clientTime === "object" ? object.clientTime.low || object.clientTime.high : $Number(object.clientTime) !== 0)
                    if ($util.Long)
                        message.clientTime = $util.Long.fromValue(object.clientTime, false);
                    else if (typeof object.clientTime === "string")
                        message.clientTime = $parseInt(object.clientTime, 10);
                    else if (typeof object.clientTime === "number")
                        message.clientTime = object.clientTime;
                    else if (typeof object.clientTime === "object")
                        message.clientTime = new $util.LongBits(object.clientTime.low >>> 0, object.clientTime.high >>> 0).toNumber();
            return message;
        };

        /**
         * Creates a plain object from a PingEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.PingEvent
         * @static
         * @param {warbase.PingEvent} message PingEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        PingEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults)
                if ($util.Long) {
                    var long = new $util.Long(0, 0, false);
                    object.clientTime = options.longs === $String ? long.toString() : options.longs === $Number ? long.toNumber() : typeof $BigInt !== "undefined" && options.longs === $BigInt ? long.toBigInt() : long;
                } else
                    object.clientTime = options.longs === $String ? "0" : typeof $BigInt !== "undefined" && options.longs === $BigInt ? $BigInt("0") : 0;
            if (message.clientTime != null && $Object.hasOwnProperty.call(message, "clientTime"))
                if (typeof $BigInt !== "undefined" && options.longs === $BigInt)
                    object.clientTime = typeof message.clientTime === "number" ? $BigInt(message.clientTime) : $util.Long.fromBits(message.clientTime.low >>> 0, message.clientTime.high >>> 0, false).toBigInt();
                else if (typeof message.clientTime === "number")
                    object.clientTime = options.longs === $String ? $String(message.clientTime) : message.clientTime;
                else
                    object.clientTime = options.longs === $String ? $util.Long.prototype.toString.call(message.clientTime) : options.longs === $Number ? new $util.LongBits(message.clientTime.low >>> 0, message.clientTime.high >>> 0).toNumber() : message.clientTime;
            return object;
        };

        /**
         * Converts this PingEvent to JSON.
         * @function toJSON
         * @memberof warbase.PingEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        PingEvent.prototype.toJSON = function() {
            return PingEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for PingEvent
         * @function getTypeUrl
         * @memberof warbase.PingEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        PingEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.PingEvent";
        };

        return PingEvent;
    })();

    warbase.ServerMessage = (function() {

        /**
         * Properties of a ServerMessage.
         * @typedef {Object} warbase.ServerMessage.$Properties
         * @property {warbase.GameState.$Properties|null} [gameState] ServerMessage gameState
         * @property {warbase.ServerEvent.$Properties|null} [serverEvent] ServerMessage serverEvent
         * @property {"gameState"|"serverEvent"} [message] ServerMessage message
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a ServerMessage.
         * @memberof warbase
         * @interface IServerMessage
         * @augments warbase.ServerMessage.$Properties
         * @deprecated Use warbase.ServerMessage.$Properties instead.
         */

        /**
         * Narrowed shape of a ServerMessage.
         * @typedef {{
         *   gameState?: warbase.GameState.$Shape|null;
         *   serverEvent?: warbase.ServerEvent.$Shape|null;
         *   $unknowns?: Array.<Uint8Array>;
         * } & (
         *   ({ message?: undefined; gameState?: null; serverEvent?: null }|{ message?: "gameState"; gameState: warbase.GameState.$Shape; serverEvent?: null }|{ message?: "serverEvent"; gameState?: null; serverEvent: warbase.ServerEvent.$Shape })
         * )} warbase.ServerMessage.$Shape
         */

        /**
         * Constructs a new ServerMessage.
         * @memberof warbase
         * @classdesc Represents a ServerMessage.
         * @constructor
         * @param {warbase.ServerMessage.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var ServerMessage = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * ServerMessage gameState.
         * @member {warbase.GameState.$Properties|null|undefined} gameState
         * @memberof warbase.ServerMessage
         * @instance
         */
        ServerMessage.prototype.gameState = null;

        /**
         * ServerMessage serverEvent.
         * @member {warbase.ServerEvent.$Properties|null|undefined} serverEvent
         * @memberof warbase.ServerMessage
         * @instance
         */
        ServerMessage.prototype.serverEvent = null;

        // OneOf field names bound to virtual getters and setters
        var $oneOfFields;

        /**
         * ServerMessage message.
         * @member {"gameState"|"serverEvent"|undefined} message
         * @memberof warbase.ServerMessage
         * @instance
         */
        $Object.defineProperty(ServerMessage.prototype, "message", {
            get: $util.oneOfGetter($oneOfFields = ["gameState", "serverEvent"]),
            set: $util.oneOfSetter($oneOfFields)
        });

        /**
         * Creates a new ServerMessage instance using the specified properties.
         * @function create
         * @memberof warbase.ServerMessage
         * @static
         * @param {warbase.ServerMessage.$Properties=} [properties] Properties to set
         * @returns {warbase.ServerMessage} ServerMessage instance
         * @type {{
         *   (properties: warbase.ServerMessage.$Shape): warbase.ServerMessage & warbase.ServerMessage.$Shape;
         *   (properties?: warbase.ServerMessage.$Properties): warbase.ServerMessage;
         * }}
         */
        ServerMessage.create = function(properties) {
            return new ServerMessage(properties);
        };

        /**
         * Encodes the specified ServerMessage message. Does not implicitly {@link warbase.ServerMessage.verify|verify} messages.
         * @function encode
         * @memberof warbase.ServerMessage
         * @static
         * @param {warbase.ServerMessage.$Properties} message ServerMessage message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ServerMessage.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.gameState != null && $Object.hasOwnProperty.call(message, "gameState"))
                $root.warbase.GameState.encode(message.gameState, writer.uint32(/* id 1, wireType 2 =*/10).fork(), _depth + 1).ldelim();
            if (message.serverEvent != null && $Object.hasOwnProperty.call(message, "serverEvent"))
                $root.warbase.ServerEvent.encode(message.serverEvent, writer.uint32(/* id 2, wireType 2 =*/18).fork(), _depth + 1).ldelim();
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified ServerMessage message, length delimited. Does not implicitly {@link warbase.ServerMessage.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.ServerMessage
         * @static
         * @param {warbase.ServerMessage.$Properties} message ServerMessage message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ServerMessage.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a ServerMessage message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.ServerMessage
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.ServerMessage & warbase.ServerMessage.$Shape} ServerMessage
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ServerMessage.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.ServerMessage();
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 2)
                            break;
                        message.gameState = $root.warbase.GameState.decode(reader, reader.uint32(), $undefined, _depth + 1, message.gameState);
                        message.message = "gameState";
                        continue;
                    }
                case 2: {
                        if (wireType !== 2)
                            break;
                        message.serverEvent = $root.warbase.ServerEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.serverEvent);
                        message.message = "serverEvent";
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a ServerMessage message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.ServerMessage
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.ServerMessage & warbase.ServerMessage.$Shape} ServerMessage
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ServerMessage.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a ServerMessage message.
         * @function verify
         * @memberof warbase.ServerMessage
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        ServerMessage.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            var properties = {};
            if (message.gameState != null && $Object.hasOwnProperty.call(message, "gameState")) {
                properties.message = 1;
                {
                    var error = $root.warbase.GameState.verify(message.gameState, _depth + 1);
                    if (error)
                        return "gameState." + error;
                }
            }
            if (message.serverEvent != null && $Object.hasOwnProperty.call(message, "serverEvent")) {
                if (properties.message === 1)
                    return "message: multiple values";
                properties.message = 1;
                {
                    var error = $root.warbase.ServerEvent.verify(message.serverEvent, _depth + 1);
                    if (error)
                        return "serverEvent." + error;
                }
            }
            return null;
        };

        /**
         * Creates a ServerMessage message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.ServerMessage
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.ServerMessage} ServerMessage
         */
        ServerMessage.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.ServerMessage)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.ServerMessage: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.ServerMessage();
            if (object.gameState != null) {
                if (!$util.isObject(object.gameState))
                    throw $TypeError(".warbase.ServerMessage.gameState: object expected");
                message.gameState = $root.warbase.GameState.fromObject(object.gameState, _depth + 1);
            }
            if (object.serverEvent != null) {
                if (!$util.isObject(object.serverEvent))
                    throw $TypeError(".warbase.ServerMessage.serverEvent: object expected");
                message.serverEvent = $root.warbase.ServerEvent.fromObject(object.serverEvent, _depth + 1);
            }
            return message;
        };

        /**
         * Creates a plain object from a ServerMessage message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.ServerMessage
         * @static
         * @param {warbase.ServerMessage} message ServerMessage
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        ServerMessage.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (message.gameState != null && $Object.hasOwnProperty.call(message, "gameState")) {
                object.gameState = $root.warbase.GameState.toObject(message.gameState, options, _depth + 1);
                if (options.oneofs)
                    object.message = "gameState";
            }
            if (message.serverEvent != null && $Object.hasOwnProperty.call(message, "serverEvent")) {
                object.serverEvent = $root.warbase.ServerEvent.toObject(message.serverEvent, options, _depth + 1);
                if (options.oneofs)
                    object.message = "serverEvent";
            }
            return object;
        };

        /**
         * Converts this ServerMessage to JSON.
         * @function toJSON
         * @memberof warbase.ServerMessage
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        ServerMessage.prototype.toJSON = function() {
            return ServerMessage.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for ServerMessage
         * @function getTypeUrl
         * @memberof warbase.ServerMessage
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        ServerMessage.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.ServerMessage";
        };

        return ServerMessage;
    })();

    warbase.GameState = (function() {

        /**
         * Properties of a GameState.
         * @typedef {Object} warbase.GameState.$Properties
         * @property {Object.<string,warbase.PlayerState.$Properties>|null} [players] GameState players
         * @property {string|null} [roomMode] GameState roomMode
         * @property {string|null} [roomState] GameState roomState
         * @property {number|null} [scoreTeamA] GameState scoreTeamA
         * @property {number|null} [scoreTeamB] GameState scoreTeamB
         * @property {string|null} [winnerId] GameState winnerId
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a GameState.
         * @memberof warbase
         * @interface IGameState
         * @augments warbase.GameState.$Properties
         * @deprecated Use warbase.GameState.$Properties instead.
         */

        /**
         * Shape of a GameState.
         * @typedef {warbase.GameState.$Properties} warbase.GameState.$Shape
         */

        /**
         * Constructs a new GameState.
         * @memberof warbase
         * @classdesc Represents a GameState.
         * @constructor
         * @param {warbase.GameState.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var GameState = function (properties) {
            this.players = {};
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * GameState players.
         * @member {Object.<string,warbase.PlayerState.$Properties>} players
         * @memberof warbase.GameState
         * @instance
         */
        GameState.prototype.players = $util.emptyObject;

        /**
         * GameState roomMode.
         * @member {string} roomMode
         * @memberof warbase.GameState
         * @instance
         */
        GameState.prototype.roomMode = "";

        /**
         * GameState roomState.
         * @member {string} roomState
         * @memberof warbase.GameState
         * @instance
         */
        GameState.prototype.roomState = "";

        /**
         * GameState scoreTeamA.
         * @member {number} scoreTeamA
         * @memberof warbase.GameState
         * @instance
         */
        GameState.prototype.scoreTeamA = 0;

        /**
         * GameState scoreTeamB.
         * @member {number} scoreTeamB
         * @memberof warbase.GameState
         * @instance
         */
        GameState.prototype.scoreTeamB = 0;

        /**
         * GameState winnerId.
         * @member {string} winnerId
         * @memberof warbase.GameState
         * @instance
         */
        GameState.prototype.winnerId = "";

        /**
         * Creates a new GameState instance using the specified properties.
         * @function create
         * @memberof warbase.GameState
         * @static
         * @param {warbase.GameState.$Properties=} [properties] Properties to set
         * @returns {warbase.GameState} GameState instance
         * @type {{
         *   (properties: warbase.GameState.$Shape): warbase.GameState & warbase.GameState.$Shape;
         *   (properties?: warbase.GameState.$Properties): warbase.GameState;
         * }}
         */
        GameState.create = function(properties) {
            return new GameState(properties);
        };

        /**
         * Encodes the specified GameState message. Does not implicitly {@link warbase.GameState.verify|verify} messages.
         * @function encode
         * @memberof warbase.GameState
         * @static
         * @param {warbase.GameState.$Properties} message GameState message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        GameState.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.players != null && $Object.hasOwnProperty.call(message, "players"))
                for (var keys = $Object.keys(message.players), i = 0; i < keys.length; ++i) {
                    writer.uint32(/* id 1, wireType 2 =*/10).fork().uint32(/* id 1, wireType 2 =*/10).string(keys[i]);
                    $root.warbase.PlayerState.encode(message.players[keys[i]], writer.uint32(/* id 2, wireType 2 =*/18).fork(), _depth + 1).ldelim().ldelim();
                }
            if (message.roomMode != null && $Object.hasOwnProperty.call(message, "roomMode") && message.roomMode !== "")
                writer.uint32(/* id 2, wireType 2 =*/18).string(message.roomMode);
            if (message.roomState != null && $Object.hasOwnProperty.call(message, "roomState") && message.roomState !== "")
                writer.uint32(/* id 3, wireType 2 =*/26).string(message.roomState);
            if (message.scoreTeamA != null && $Object.hasOwnProperty.call(message, "scoreTeamA") && message.scoreTeamA !== 0)
                writer.uint32(/* id 4, wireType 0 =*/32).int32(message.scoreTeamA);
            if (message.scoreTeamB != null && $Object.hasOwnProperty.call(message, "scoreTeamB") && message.scoreTeamB !== 0)
                writer.uint32(/* id 5, wireType 0 =*/40).int32(message.scoreTeamB);
            if (message.winnerId != null && $Object.hasOwnProperty.call(message, "winnerId") && message.winnerId !== "")
                writer.uint32(/* id 6, wireType 2 =*/50).string(message.winnerId);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified GameState message, length delimited. Does not implicitly {@link warbase.GameState.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.GameState
         * @static
         * @param {warbase.GameState.$Properties} message GameState message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        GameState.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a GameState message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.GameState
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.GameState & warbase.GameState.$Shape} GameState
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        GameState.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.GameState(), key, value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 2)
                            break;
                        if (message.players === $util.emptyObject)
                            message.players = {};
                        var end2 = reader.uint32() + reader.pos;
                        key = "";
                        value = null;
                        while (reader.pos < end2) {
                            var tag2 = reader.tag();
                            wireType = tag2 & 7;
                            switch (tag2 >>>= 3) {
                            case 1:
                                if (wireType !== 2)
                                    break;
                                key = reader.stringVerify();
                                continue;
                            case 2:
                                if (wireType !== 2)
                                    break;
                                value = $root.warbase.PlayerState.decode(reader, reader.uint32(), $undefined, _depth + 1, value);
                                continue;
                            }
                            reader.skipType(wireType, _depth, tag2);
                        }
                        if (key === "__proto__")
                            $util.makeProp(message.players, key);
                        message.players[key] = value || new $root.warbase.PlayerState();
                        continue;
                    }
                case 2: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.roomMode = value;
                        else
                            delete message.roomMode;
                        continue;
                    }
                case 3: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.roomState = value;
                        else
                            delete message.roomState;
                        continue;
                    }
                case 4: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.int32())
                            message.scoreTeamA = value;
                        else
                            delete message.scoreTeamA;
                        continue;
                    }
                case 5: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.int32())
                            message.scoreTeamB = value;
                        else
                            delete message.scoreTeamB;
                        continue;
                    }
                case 6: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.winnerId = value;
                        else
                            delete message.winnerId;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a GameState message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.GameState
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.GameState & warbase.GameState.$Shape} GameState
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        GameState.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a GameState message.
         * @function verify
         * @memberof warbase.GameState
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        GameState.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.players != null && $Object.hasOwnProperty.call(message, "players")) {
                if (!$util.isObject(message.players))
                    return "players: object expected";
                var key = $Object.keys(message.players);
                for (var i = 0; i < key.length; ++i) {
                    var error = $root.warbase.PlayerState.verify(message.players[key[i]], _depth + 1);
                    if (error)
                        return "players." + error;
                }
            }
            if (message.roomMode != null && $Object.hasOwnProperty.call(message, "roomMode"))
                if (!$util.isString(message.roomMode))
                    return "roomMode: string expected";
            if (message.roomState != null && $Object.hasOwnProperty.call(message, "roomState"))
                if (!$util.isString(message.roomState))
                    return "roomState: string expected";
            if (message.scoreTeamA != null && $Object.hasOwnProperty.call(message, "scoreTeamA"))
                if (!$util.isInteger(message.scoreTeamA))
                    return "scoreTeamA: integer expected";
            if (message.scoreTeamB != null && $Object.hasOwnProperty.call(message, "scoreTeamB"))
                if (!$util.isInteger(message.scoreTeamB))
                    return "scoreTeamB: integer expected";
            if (message.winnerId != null && $Object.hasOwnProperty.call(message, "winnerId"))
                if (!$util.isString(message.winnerId))
                    return "winnerId: string expected";
            return null;
        };

        /**
         * Creates a GameState message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.GameState
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.GameState} GameState
         */
        GameState.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.GameState)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.GameState: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.GameState();
            if (object.players) {
                if (!$util.isObject(object.players))
                    throw $TypeError(".warbase.GameState.players: object expected");
                message.players = {};
                for (var keys = $Object.keys(object.players), i = 0; i < keys.length; ++i) {
                    if (keys[i] === "__proto__")
                        $util.makeProp(message.players, keys[i]);
                    if (!$util.isObject(object.players[keys[i]]))
                        throw $TypeError(".warbase.GameState.players: object expected");
                    message.players[keys[i]] = $root.warbase.PlayerState.fromObject(object.players[keys[i]], _depth + 1);
                }
            }
            if (object.roomMode != null)
                if (typeof object.roomMode !== "string" || object.roomMode.length)
                    message.roomMode = $String(object.roomMode);
            if (object.roomState != null)
                if (typeof object.roomState !== "string" || object.roomState.length)
                    message.roomState = $String(object.roomState);
            if (object.scoreTeamA != null)
                if ($Number(object.scoreTeamA) !== 0)
                    message.scoreTeamA = object.scoreTeamA | 0;
            if (object.scoreTeamB != null)
                if ($Number(object.scoreTeamB) !== 0)
                    message.scoreTeamB = object.scoreTeamB | 0;
            if (object.winnerId != null)
                if (typeof object.winnerId !== "string" || object.winnerId.length)
                    message.winnerId = $String(object.winnerId);
            return message;
        };

        /**
         * Creates a plain object from a GameState message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.GameState
         * @static
         * @param {warbase.GameState} message GameState
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        GameState.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.objects || options.defaults)
                object.players = {};
            if (options.defaults) {
                object.roomMode = "";
                object.roomState = "";
                object.scoreTeamA = 0;
                object.scoreTeamB = 0;
                object.winnerId = "";
            }
            var keys2;
            if (message.players && (keys2 = $Object.keys(message.players)).length) {
                object.players = {};
                for (var j = 0; j < keys2.length; ++j) {
                    if (keys2[j] === "__proto__")
                        $util.makeProp(object.players, keys2[j]);
                    object.players[keys2[j]] = $root.warbase.PlayerState.toObject(message.players[keys2[j]], options, _depth + 1);
                }
            }
            if (message.roomMode != null && $Object.hasOwnProperty.call(message, "roomMode"))
                object.roomMode = message.roomMode;
            if (message.roomState != null && $Object.hasOwnProperty.call(message, "roomState"))
                object.roomState = message.roomState;
            if (message.scoreTeamA != null && $Object.hasOwnProperty.call(message, "scoreTeamA"))
                object.scoreTeamA = message.scoreTeamA;
            if (message.scoreTeamB != null && $Object.hasOwnProperty.call(message, "scoreTeamB"))
                object.scoreTeamB = message.scoreTeamB;
            if (message.winnerId != null && $Object.hasOwnProperty.call(message, "winnerId"))
                object.winnerId = message.winnerId;
            return object;
        };

        /**
         * Converts this GameState to JSON.
         * @function toJSON
         * @memberof warbase.GameState
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        GameState.prototype.toJSON = function() {
            return GameState.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for GameState
         * @function getTypeUrl
         * @memberof warbase.GameState
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        GameState.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.GameState";
        };

        return GameState;
    })();

    warbase.PlayerState = (function() {

        /**
         * Properties of a PlayerState.
         * @typedef {Object} warbase.PlayerState.$Properties
         * @property {number|null} [x] PlayerState x
         * @property {number|null} [y] PlayerState y
         * @property {number|null} [z] PlayerState z
         * @property {number|null} [rx] PlayerState rx
         * @property {number|null} [ry] PlayerState ry
         * @property {number|null} [rz] PlayerState rz
         * @property {number|null} [rw] PlayerState rw
         * @property {string|null} [animation] PlayerState animation
         * @property {number|null} [health] PlayerState health
         * @property {number|null} [kills] PlayerState kills
         * @property {number|null} [deaths] PlayerState deaths
         * @property {boolean|null} [isDead] PlayerState isDead
         * @property {string|null} [platformId] PlayerState platformId
         * @property {number|null} [ping] PlayerState ping
         * @property {string|null} [weaponId] PlayerState weaponId
         * @property {string|null} [team] PlayerState team
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a PlayerState.
         * @memberof warbase
         * @interface IPlayerState
         * @augments warbase.PlayerState.$Properties
         * @deprecated Use warbase.PlayerState.$Properties instead.
         */

        /**
         * Shape of a PlayerState.
         * @typedef {warbase.PlayerState.$Properties} warbase.PlayerState.$Shape
         */

        /**
         * Constructs a new PlayerState.
         * @memberof warbase
         * @classdesc Represents a PlayerState.
         * @constructor
         * @param {warbase.PlayerState.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var PlayerState = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * PlayerState x.
         * @member {number} x
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.x = 0;

        /**
         * PlayerState y.
         * @member {number} y
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.y = 0;

        /**
         * PlayerState z.
         * @member {number} z
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.z = 0;

        /**
         * PlayerState rx.
         * @member {number} rx
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.rx = 0;

        /**
         * PlayerState ry.
         * @member {number} ry
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.ry = 0;

        /**
         * PlayerState rz.
         * @member {number} rz
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.rz = 0;

        /**
         * PlayerState rw.
         * @member {number} rw
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.rw = 0;

        /**
         * PlayerState animation.
         * @member {string} animation
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.animation = "";

        /**
         * PlayerState health.
         * @member {number} health
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.health = 0;

        /**
         * PlayerState kills.
         * @member {number} kills
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.kills = 0;

        /**
         * PlayerState deaths.
         * @member {number} deaths
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.deaths = 0;

        /**
         * PlayerState isDead.
         * @member {boolean} isDead
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.isDead = false;

        /**
         * PlayerState platformId.
         * @member {string} platformId
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.platformId = "";

        /**
         * PlayerState ping.
         * @member {number} ping
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.ping = 0;

        /**
         * PlayerState weaponId.
         * @member {string} weaponId
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.weaponId = "";

        /**
         * PlayerState team.
         * @member {string} team
         * @memberof warbase.PlayerState
         * @instance
         */
        PlayerState.prototype.team = "";

        /**
         * Creates a new PlayerState instance using the specified properties.
         * @function create
         * @memberof warbase.PlayerState
         * @static
         * @param {warbase.PlayerState.$Properties=} [properties] Properties to set
         * @returns {warbase.PlayerState} PlayerState instance
         * @type {{
         *   (properties: warbase.PlayerState.$Shape): warbase.PlayerState & warbase.PlayerState.$Shape;
         *   (properties?: warbase.PlayerState.$Properties): warbase.PlayerState;
         * }}
         */
        PlayerState.create = function(properties) {
            return new PlayerState(properties);
        };

        /**
         * Encodes the specified PlayerState message. Does not implicitly {@link warbase.PlayerState.verify|verify} messages.
         * @function encode
         * @memberof warbase.PlayerState
         * @static
         * @param {warbase.PlayerState.$Properties} message PlayerState message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        PlayerState.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.x != null && $Object.hasOwnProperty.call(message, "x") && !$Object.is(message.x, 0))
                writer.uint32(/* id 1, wireType 5 =*/13).float(message.x);
            if (message.y != null && $Object.hasOwnProperty.call(message, "y") && !$Object.is(message.y, 0))
                writer.uint32(/* id 2, wireType 5 =*/21).float(message.y);
            if (message.z != null && $Object.hasOwnProperty.call(message, "z") && !$Object.is(message.z, 0))
                writer.uint32(/* id 3, wireType 5 =*/29).float(message.z);
            if (message.rx != null && $Object.hasOwnProperty.call(message, "rx") && !$Object.is(message.rx, 0))
                writer.uint32(/* id 4, wireType 5 =*/37).float(message.rx);
            if (message.ry != null && $Object.hasOwnProperty.call(message, "ry") && !$Object.is(message.ry, 0))
                writer.uint32(/* id 5, wireType 5 =*/45).float(message.ry);
            if (message.rz != null && $Object.hasOwnProperty.call(message, "rz") && !$Object.is(message.rz, 0))
                writer.uint32(/* id 6, wireType 5 =*/53).float(message.rz);
            if (message.rw != null && $Object.hasOwnProperty.call(message, "rw") && !$Object.is(message.rw, 0))
                writer.uint32(/* id 7, wireType 5 =*/61).float(message.rw);
            if (message.animation != null && $Object.hasOwnProperty.call(message, "animation") && message.animation !== "")
                writer.uint32(/* id 8, wireType 2 =*/66).string(message.animation);
            if (message.health != null && $Object.hasOwnProperty.call(message, "health") && message.health !== 0)
                writer.uint32(/* id 9, wireType 0 =*/72).int32(message.health);
            if (message.kills != null && $Object.hasOwnProperty.call(message, "kills") && message.kills !== 0)
                writer.uint32(/* id 10, wireType 0 =*/80).int32(message.kills);
            if (message.deaths != null && $Object.hasOwnProperty.call(message, "deaths") && message.deaths !== 0)
                writer.uint32(/* id 11, wireType 0 =*/88).int32(message.deaths);
            if (message.isDead != null && $Object.hasOwnProperty.call(message, "isDead") && message.isDead !== false)
                writer.uint32(/* id 12, wireType 0 =*/96).bool(message.isDead);
            if (message.platformId != null && $Object.hasOwnProperty.call(message, "platformId") && message.platformId !== "")
                writer.uint32(/* id 13, wireType 2 =*/106).string(message.platformId);
            if (message.ping != null && $Object.hasOwnProperty.call(message, "ping") && message.ping !== 0)
                writer.uint32(/* id 14, wireType 0 =*/112).int32(message.ping);
            if (message.weaponId != null && $Object.hasOwnProperty.call(message, "weaponId") && message.weaponId !== "")
                writer.uint32(/* id 15, wireType 2 =*/122).string(message.weaponId);
            if (message.team != null && $Object.hasOwnProperty.call(message, "team") && message.team !== "")
                writer.uint32(/* id 16, wireType 2 =*/130).string(message.team);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified PlayerState message, length delimited. Does not implicitly {@link warbase.PlayerState.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.PlayerState
         * @static
         * @param {warbase.PlayerState.$Properties} message PlayerState message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        PlayerState.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a PlayerState message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.PlayerState
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.PlayerState & warbase.PlayerState.$Shape} PlayerState
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        PlayerState.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.PlayerState(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.x = value;
                        else
                            delete message.x;
                        continue;
                    }
                case 2: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.y = value;
                        else
                            delete message.y;
                        continue;
                    }
                case 3: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.z = value;
                        else
                            delete message.z;
                        continue;
                    }
                case 4: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.rx = value;
                        else
                            delete message.rx;
                        continue;
                    }
                case 5: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.ry = value;
                        else
                            delete message.ry;
                        continue;
                    }
                case 6: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.rz = value;
                        else
                            delete message.rz;
                        continue;
                    }
                case 7: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.rw = value;
                        else
                            delete message.rw;
                        continue;
                    }
                case 8: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.animation = value;
                        else
                            delete message.animation;
                        continue;
                    }
                case 9: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.int32())
                            message.health = value;
                        else
                            delete message.health;
                        continue;
                    }
                case 10: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.int32())
                            message.kills = value;
                        else
                            delete message.kills;
                        continue;
                    }
                case 11: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.int32())
                            message.deaths = value;
                        else
                            delete message.deaths;
                        continue;
                    }
                case 12: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.bool())
                            message.isDead = value;
                        else
                            delete message.isDead;
                        continue;
                    }
                case 13: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.platformId = value;
                        else
                            delete message.platformId;
                        continue;
                    }
                case 14: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.int32())
                            message.ping = value;
                        else
                            delete message.ping;
                        continue;
                    }
                case 15: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.weaponId = value;
                        else
                            delete message.weaponId;
                        continue;
                    }
                case 16: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.team = value;
                        else
                            delete message.team;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a PlayerState message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.PlayerState
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.PlayerState & warbase.PlayerState.$Shape} PlayerState
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        PlayerState.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a PlayerState message.
         * @function verify
         * @memberof warbase.PlayerState
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        PlayerState.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.x != null && $Object.hasOwnProperty.call(message, "x"))
                if (typeof message.x !== "number")
                    return "x: number expected";
            if (message.y != null && $Object.hasOwnProperty.call(message, "y"))
                if (typeof message.y !== "number")
                    return "y: number expected";
            if (message.z != null && $Object.hasOwnProperty.call(message, "z"))
                if (typeof message.z !== "number")
                    return "z: number expected";
            if (message.rx != null && $Object.hasOwnProperty.call(message, "rx"))
                if (typeof message.rx !== "number")
                    return "rx: number expected";
            if (message.ry != null && $Object.hasOwnProperty.call(message, "ry"))
                if (typeof message.ry !== "number")
                    return "ry: number expected";
            if (message.rz != null && $Object.hasOwnProperty.call(message, "rz"))
                if (typeof message.rz !== "number")
                    return "rz: number expected";
            if (message.rw != null && $Object.hasOwnProperty.call(message, "rw"))
                if (typeof message.rw !== "number")
                    return "rw: number expected";
            if (message.animation != null && $Object.hasOwnProperty.call(message, "animation"))
                if (!$util.isString(message.animation))
                    return "animation: string expected";
            if (message.health != null && $Object.hasOwnProperty.call(message, "health"))
                if (!$util.isInteger(message.health))
                    return "health: integer expected";
            if (message.kills != null && $Object.hasOwnProperty.call(message, "kills"))
                if (!$util.isInteger(message.kills))
                    return "kills: integer expected";
            if (message.deaths != null && $Object.hasOwnProperty.call(message, "deaths"))
                if (!$util.isInteger(message.deaths))
                    return "deaths: integer expected";
            if (message.isDead != null && $Object.hasOwnProperty.call(message, "isDead"))
                if (typeof message.isDead !== "boolean")
                    return "isDead: boolean expected";
            if (message.platformId != null && $Object.hasOwnProperty.call(message, "platformId"))
                if (!$util.isString(message.platformId))
                    return "platformId: string expected";
            if (message.ping != null && $Object.hasOwnProperty.call(message, "ping"))
                if (!$util.isInteger(message.ping))
                    return "ping: integer expected";
            if (message.weaponId != null && $Object.hasOwnProperty.call(message, "weaponId"))
                if (!$util.isString(message.weaponId))
                    return "weaponId: string expected";
            if (message.team != null && $Object.hasOwnProperty.call(message, "team"))
                if (!$util.isString(message.team))
                    return "team: string expected";
            return null;
        };

        /**
         * Creates a PlayerState message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.PlayerState
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.PlayerState} PlayerState
         */
        PlayerState.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.PlayerState)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.PlayerState: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.PlayerState();
            if (object.x != null)
                if (!$Object.is($Number(object.x), 0))
                    message.x = $Number(object.x);
            if (object.y != null)
                if (!$Object.is($Number(object.y), 0))
                    message.y = $Number(object.y);
            if (object.z != null)
                if (!$Object.is($Number(object.z), 0))
                    message.z = $Number(object.z);
            if (object.rx != null)
                if (!$Object.is($Number(object.rx), 0))
                    message.rx = $Number(object.rx);
            if (object.ry != null)
                if (!$Object.is($Number(object.ry), 0))
                    message.ry = $Number(object.ry);
            if (object.rz != null)
                if (!$Object.is($Number(object.rz), 0))
                    message.rz = $Number(object.rz);
            if (object.rw != null)
                if (!$Object.is($Number(object.rw), 0))
                    message.rw = $Number(object.rw);
            if (object.animation != null)
                if (typeof object.animation !== "string" || object.animation.length)
                    message.animation = $String(object.animation);
            if (object.health != null)
                if ($Number(object.health) !== 0)
                    message.health = object.health | 0;
            if (object.kills != null)
                if ($Number(object.kills) !== 0)
                    message.kills = object.kills | 0;
            if (object.deaths != null)
                if ($Number(object.deaths) !== 0)
                    message.deaths = object.deaths | 0;
            if (object.isDead != null)
                if (object.isDead)
                    message.isDead = $Boolean(object.isDead);
            if (object.platformId != null)
                if (typeof object.platformId !== "string" || object.platformId.length)
                    message.platformId = $String(object.platformId);
            if (object.ping != null)
                if ($Number(object.ping) !== 0)
                    message.ping = object.ping | 0;
            if (object.weaponId != null)
                if (typeof object.weaponId !== "string" || object.weaponId.length)
                    message.weaponId = $String(object.weaponId);
            if (object.team != null)
                if (typeof object.team !== "string" || object.team.length)
                    message.team = $String(object.team);
            return message;
        };

        /**
         * Creates a plain object from a PlayerState message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.PlayerState
         * @static
         * @param {warbase.PlayerState} message PlayerState
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        PlayerState.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults) {
                object.x = 0;
                object.y = 0;
                object.z = 0;
                object.rx = 0;
                object.ry = 0;
                object.rz = 0;
                object.rw = 0;
                object.animation = "";
                object.health = 0;
                object.kills = 0;
                object.deaths = 0;
                object.isDead = false;
                object.platformId = "";
                object.ping = 0;
                object.weaponId = "";
                object.team = "";
            }
            if (message.x != null && $Object.hasOwnProperty.call(message, "x"))
                object.x = options.json && !$isFinite(message.x) ? $String(message.x) : message.x;
            if (message.y != null && $Object.hasOwnProperty.call(message, "y"))
                object.y = options.json && !$isFinite(message.y) ? $String(message.y) : message.y;
            if (message.z != null && $Object.hasOwnProperty.call(message, "z"))
                object.z = options.json && !$isFinite(message.z) ? $String(message.z) : message.z;
            if (message.rx != null && $Object.hasOwnProperty.call(message, "rx"))
                object.rx = options.json && !$isFinite(message.rx) ? $String(message.rx) : message.rx;
            if (message.ry != null && $Object.hasOwnProperty.call(message, "ry"))
                object.ry = options.json && !$isFinite(message.ry) ? $String(message.ry) : message.ry;
            if (message.rz != null && $Object.hasOwnProperty.call(message, "rz"))
                object.rz = options.json && !$isFinite(message.rz) ? $String(message.rz) : message.rz;
            if (message.rw != null && $Object.hasOwnProperty.call(message, "rw"))
                object.rw = options.json && !$isFinite(message.rw) ? $String(message.rw) : message.rw;
            if (message.animation != null && $Object.hasOwnProperty.call(message, "animation"))
                object.animation = message.animation;
            if (message.health != null && $Object.hasOwnProperty.call(message, "health"))
                object.health = message.health;
            if (message.kills != null && $Object.hasOwnProperty.call(message, "kills"))
                object.kills = message.kills;
            if (message.deaths != null && $Object.hasOwnProperty.call(message, "deaths"))
                object.deaths = message.deaths;
            if (message.isDead != null && $Object.hasOwnProperty.call(message, "isDead"))
                object.isDead = message.isDead;
            if (message.platformId != null && $Object.hasOwnProperty.call(message, "platformId"))
                object.platformId = message.platformId;
            if (message.ping != null && $Object.hasOwnProperty.call(message, "ping"))
                object.ping = message.ping;
            if (message.weaponId != null && $Object.hasOwnProperty.call(message, "weaponId"))
                object.weaponId = message.weaponId;
            if (message.team != null && $Object.hasOwnProperty.call(message, "team"))
                object.team = message.team;
            return object;
        };

        /**
         * Converts this PlayerState to JSON.
         * @function toJSON
         * @memberof warbase.PlayerState
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        PlayerState.prototype.toJSON = function() {
            return PlayerState.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for PlayerState
         * @function getTypeUrl
         * @memberof warbase.PlayerState
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        PlayerState.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.PlayerState";
        };

        return PlayerState;
    })();

    warbase.ServerEvent = (function() {

        /**
         * Properties of a ServerEvent.
         * @typedef {Object} warbase.ServerEvent.$Properties
         * @property {warbase.RespawnEvent.$Properties|null} [respawn] ServerEvent respawn
         * @property {warbase.ServerFireEvent.$Properties|null} [fire] ServerEvent fire
         * @property {warbase.HitConfirmedEvent.$Properties|null} [hitConfirmed] ServerEvent hitConfirmed
         * @property {warbase.KillConfirmedEvent.$Properties|null} [killConfirmed] ServerEvent killConfirmed
         * @property {warbase.ServerThrowGrenadeEvent.$Properties|null} [throwGrenade] ServerEvent throwGrenade
         * @property {warbase.ServerPongEvent.$Properties|null} [pong] ServerEvent pong
         * @property {"respawn"|"fire"|"hitConfirmed"|"killConfirmed"|"throwGrenade"|"pong"} [event] ServerEvent event
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a ServerEvent.
         * @memberof warbase
         * @interface IServerEvent
         * @augments warbase.ServerEvent.$Properties
         * @deprecated Use warbase.ServerEvent.$Properties instead.
         */

        /**
         * Narrowed shape of a ServerEvent.
         * @typedef {{
         *   respawn?: warbase.RespawnEvent.$Shape|null;
         *   fire?: warbase.ServerFireEvent.$Shape|null;
         *   hitConfirmed?: warbase.HitConfirmedEvent.$Shape|null;
         *   killConfirmed?: warbase.KillConfirmedEvent.$Shape|null;
         *   throwGrenade?: warbase.ServerThrowGrenadeEvent.$Shape|null;
         *   pong?: warbase.ServerPongEvent.$Shape|null;
         *   $unknowns?: Array.<Uint8Array>;
         * } & (
         *   ({ event?: undefined; respawn?: null; fire?: null; hitConfirmed?: null; killConfirmed?: null; throwGrenade?: null; pong?: null }|{ event?: "respawn"; respawn: warbase.RespawnEvent.$Shape; fire?: null; hitConfirmed?: null; killConfirmed?: null; throwGrenade?: null; pong?: null }|{ event?: "fire"; respawn?: null; fire: warbase.ServerFireEvent.$Shape; hitConfirmed?: null; killConfirmed?: null; throwGrenade?: null; pong?: null }|{ event?: "hitConfirmed"; respawn?: null; fire?: null; hitConfirmed: warbase.HitConfirmedEvent.$Shape; killConfirmed?: null; throwGrenade?: null; pong?: null }|{ event?: "killConfirmed"; respawn?: null; fire?: null; hitConfirmed?: null; killConfirmed: warbase.KillConfirmedEvent.$Shape; throwGrenade?: null; pong?: null }|{ event?: "throwGrenade"; respawn?: null; fire?: null; hitConfirmed?: null; killConfirmed?: null; throwGrenade: warbase.ServerThrowGrenadeEvent.$Shape; pong?: null }|{ event?: "pong"; respawn?: null; fire?: null; hitConfirmed?: null; killConfirmed?: null; throwGrenade?: null; pong: warbase.ServerPongEvent.$Shape })
         * )} warbase.ServerEvent.$Shape
         */

        /**
         * Constructs a new ServerEvent.
         * @memberof warbase
         * @classdesc Represents a ServerEvent.
         * @constructor
         * @param {warbase.ServerEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var ServerEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * ServerEvent respawn.
         * @member {warbase.RespawnEvent.$Properties|null|undefined} respawn
         * @memberof warbase.ServerEvent
         * @instance
         */
        ServerEvent.prototype.respawn = null;

        /**
         * ServerEvent fire.
         * @member {warbase.ServerFireEvent.$Properties|null|undefined} fire
         * @memberof warbase.ServerEvent
         * @instance
         */
        ServerEvent.prototype.fire = null;

        /**
         * ServerEvent hitConfirmed.
         * @member {warbase.HitConfirmedEvent.$Properties|null|undefined} hitConfirmed
         * @memberof warbase.ServerEvent
         * @instance
         */
        ServerEvent.prototype.hitConfirmed = null;

        /**
         * ServerEvent killConfirmed.
         * @member {warbase.KillConfirmedEvent.$Properties|null|undefined} killConfirmed
         * @memberof warbase.ServerEvent
         * @instance
         */
        ServerEvent.prototype.killConfirmed = null;

        /**
         * ServerEvent throwGrenade.
         * @member {warbase.ServerThrowGrenadeEvent.$Properties|null|undefined} throwGrenade
         * @memberof warbase.ServerEvent
         * @instance
         */
        ServerEvent.prototype.throwGrenade = null;

        /**
         * ServerEvent pong.
         * @member {warbase.ServerPongEvent.$Properties|null|undefined} pong
         * @memberof warbase.ServerEvent
         * @instance
         */
        ServerEvent.prototype.pong = null;

        // OneOf field names bound to virtual getters and setters
        var $oneOfFields;

        /**
         * ServerEvent event.
         * @member {"respawn"|"fire"|"hitConfirmed"|"killConfirmed"|"throwGrenade"|"pong"|undefined} event
         * @memberof warbase.ServerEvent
         * @instance
         */
        $Object.defineProperty(ServerEvent.prototype, "event", {
            get: $util.oneOfGetter($oneOfFields = ["respawn", "fire", "hitConfirmed", "killConfirmed", "throwGrenade", "pong"]),
            set: $util.oneOfSetter($oneOfFields)
        });

        /**
         * Creates a new ServerEvent instance using the specified properties.
         * @function create
         * @memberof warbase.ServerEvent
         * @static
         * @param {warbase.ServerEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.ServerEvent} ServerEvent instance
         * @type {{
         *   (properties: warbase.ServerEvent.$Shape): warbase.ServerEvent & warbase.ServerEvent.$Shape;
         *   (properties?: warbase.ServerEvent.$Properties): warbase.ServerEvent;
         * }}
         */
        ServerEvent.create = function(properties) {
            return new ServerEvent(properties);
        };

        /**
         * Encodes the specified ServerEvent message. Does not implicitly {@link warbase.ServerEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.ServerEvent
         * @static
         * @param {warbase.ServerEvent.$Properties} message ServerEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ServerEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.respawn != null && $Object.hasOwnProperty.call(message, "respawn"))
                $root.warbase.RespawnEvent.encode(message.respawn, writer.uint32(/* id 1, wireType 2 =*/10).fork(), _depth + 1).ldelim();
            if (message.fire != null && $Object.hasOwnProperty.call(message, "fire"))
                $root.warbase.ServerFireEvent.encode(message.fire, writer.uint32(/* id 2, wireType 2 =*/18).fork(), _depth + 1).ldelim();
            if (message.hitConfirmed != null && $Object.hasOwnProperty.call(message, "hitConfirmed"))
                $root.warbase.HitConfirmedEvent.encode(message.hitConfirmed, writer.uint32(/* id 3, wireType 2 =*/26).fork(), _depth + 1).ldelim();
            if (message.killConfirmed != null && $Object.hasOwnProperty.call(message, "killConfirmed"))
                $root.warbase.KillConfirmedEvent.encode(message.killConfirmed, writer.uint32(/* id 4, wireType 2 =*/34).fork(), _depth + 1).ldelim();
            if (message.throwGrenade != null && $Object.hasOwnProperty.call(message, "throwGrenade"))
                $root.warbase.ServerThrowGrenadeEvent.encode(message.throwGrenade, writer.uint32(/* id 5, wireType 2 =*/42).fork(), _depth + 1).ldelim();
            if (message.pong != null && $Object.hasOwnProperty.call(message, "pong"))
                $root.warbase.ServerPongEvent.encode(message.pong, writer.uint32(/* id 6, wireType 2 =*/50).fork(), _depth + 1).ldelim();
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified ServerEvent message, length delimited. Does not implicitly {@link warbase.ServerEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.ServerEvent
         * @static
         * @param {warbase.ServerEvent.$Properties} message ServerEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ServerEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a ServerEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.ServerEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.ServerEvent & warbase.ServerEvent.$Shape} ServerEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ServerEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.ServerEvent();
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 2)
                            break;
                        message.respawn = $root.warbase.RespawnEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.respawn);
                        message.event = "respawn";
                        continue;
                    }
                case 2: {
                        if (wireType !== 2)
                            break;
                        message.fire = $root.warbase.ServerFireEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.fire);
                        message.event = "fire";
                        continue;
                    }
                case 3: {
                        if (wireType !== 2)
                            break;
                        message.hitConfirmed = $root.warbase.HitConfirmedEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.hitConfirmed);
                        message.event = "hitConfirmed";
                        continue;
                    }
                case 4: {
                        if (wireType !== 2)
                            break;
                        message.killConfirmed = $root.warbase.KillConfirmedEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.killConfirmed);
                        message.event = "killConfirmed";
                        continue;
                    }
                case 5: {
                        if (wireType !== 2)
                            break;
                        message.throwGrenade = $root.warbase.ServerThrowGrenadeEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.throwGrenade);
                        message.event = "throwGrenade";
                        continue;
                    }
                case 6: {
                        if (wireType !== 2)
                            break;
                        message.pong = $root.warbase.ServerPongEvent.decode(reader, reader.uint32(), $undefined, _depth + 1, message.pong);
                        message.event = "pong";
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a ServerEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.ServerEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.ServerEvent & warbase.ServerEvent.$Shape} ServerEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ServerEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a ServerEvent message.
         * @function verify
         * @memberof warbase.ServerEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        ServerEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            var properties = {};
            if (message.respawn != null && $Object.hasOwnProperty.call(message, "respawn")) {
                properties.event = 1;
                {
                    var error = $root.warbase.RespawnEvent.verify(message.respawn, _depth + 1);
                    if (error)
                        return "respawn." + error;
                }
            }
            if (message.fire != null && $Object.hasOwnProperty.call(message, "fire")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.ServerFireEvent.verify(message.fire, _depth + 1);
                    if (error)
                        return "fire." + error;
                }
            }
            if (message.hitConfirmed != null && $Object.hasOwnProperty.call(message, "hitConfirmed")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.HitConfirmedEvent.verify(message.hitConfirmed, _depth + 1);
                    if (error)
                        return "hitConfirmed." + error;
                }
            }
            if (message.killConfirmed != null && $Object.hasOwnProperty.call(message, "killConfirmed")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.KillConfirmedEvent.verify(message.killConfirmed, _depth + 1);
                    if (error)
                        return "killConfirmed." + error;
                }
            }
            if (message.throwGrenade != null && $Object.hasOwnProperty.call(message, "throwGrenade")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.ServerThrowGrenadeEvent.verify(message.throwGrenade, _depth + 1);
                    if (error)
                        return "throwGrenade." + error;
                }
            }
            if (message.pong != null && $Object.hasOwnProperty.call(message, "pong")) {
                if (properties.event === 1)
                    return "event: multiple values";
                properties.event = 1;
                {
                    var error = $root.warbase.ServerPongEvent.verify(message.pong, _depth + 1);
                    if (error)
                        return "pong." + error;
                }
            }
            return null;
        };

        /**
         * Creates a ServerEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.ServerEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.ServerEvent} ServerEvent
         */
        ServerEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.ServerEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.ServerEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.ServerEvent();
            if (object.respawn != null) {
                if (!$util.isObject(object.respawn))
                    throw $TypeError(".warbase.ServerEvent.respawn: object expected");
                message.respawn = $root.warbase.RespawnEvent.fromObject(object.respawn, _depth + 1);
            }
            if (object.fire != null) {
                if (!$util.isObject(object.fire))
                    throw $TypeError(".warbase.ServerEvent.fire: object expected");
                message.fire = $root.warbase.ServerFireEvent.fromObject(object.fire, _depth + 1);
            }
            if (object.hitConfirmed != null) {
                if (!$util.isObject(object.hitConfirmed))
                    throw $TypeError(".warbase.ServerEvent.hitConfirmed: object expected");
                message.hitConfirmed = $root.warbase.HitConfirmedEvent.fromObject(object.hitConfirmed, _depth + 1);
            }
            if (object.killConfirmed != null) {
                if (!$util.isObject(object.killConfirmed))
                    throw $TypeError(".warbase.ServerEvent.killConfirmed: object expected");
                message.killConfirmed = $root.warbase.KillConfirmedEvent.fromObject(object.killConfirmed, _depth + 1);
            }
            if (object.throwGrenade != null) {
                if (!$util.isObject(object.throwGrenade))
                    throw $TypeError(".warbase.ServerEvent.throwGrenade: object expected");
                message.throwGrenade = $root.warbase.ServerThrowGrenadeEvent.fromObject(object.throwGrenade, _depth + 1);
            }
            if (object.pong != null) {
                if (!$util.isObject(object.pong))
                    throw $TypeError(".warbase.ServerEvent.pong: object expected");
                message.pong = $root.warbase.ServerPongEvent.fromObject(object.pong, _depth + 1);
            }
            return message;
        };

        /**
         * Creates a plain object from a ServerEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.ServerEvent
         * @static
         * @param {warbase.ServerEvent} message ServerEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        ServerEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (message.respawn != null && $Object.hasOwnProperty.call(message, "respawn")) {
                object.respawn = $root.warbase.RespawnEvent.toObject(message.respawn, options, _depth + 1);
                if (options.oneofs)
                    object.event = "respawn";
            }
            if (message.fire != null && $Object.hasOwnProperty.call(message, "fire")) {
                object.fire = $root.warbase.ServerFireEvent.toObject(message.fire, options, _depth + 1);
                if (options.oneofs)
                    object.event = "fire";
            }
            if (message.hitConfirmed != null && $Object.hasOwnProperty.call(message, "hitConfirmed")) {
                object.hitConfirmed = $root.warbase.HitConfirmedEvent.toObject(message.hitConfirmed, options, _depth + 1);
                if (options.oneofs)
                    object.event = "hitConfirmed";
            }
            if (message.killConfirmed != null && $Object.hasOwnProperty.call(message, "killConfirmed")) {
                object.killConfirmed = $root.warbase.KillConfirmedEvent.toObject(message.killConfirmed, options, _depth + 1);
                if (options.oneofs)
                    object.event = "killConfirmed";
            }
            if (message.throwGrenade != null && $Object.hasOwnProperty.call(message, "throwGrenade")) {
                object.throwGrenade = $root.warbase.ServerThrowGrenadeEvent.toObject(message.throwGrenade, options, _depth + 1);
                if (options.oneofs)
                    object.event = "throwGrenade";
            }
            if (message.pong != null && $Object.hasOwnProperty.call(message, "pong")) {
                object.pong = $root.warbase.ServerPongEvent.toObject(message.pong, options, _depth + 1);
                if (options.oneofs)
                    object.event = "pong";
            }
            return object;
        };

        /**
         * Converts this ServerEvent to JSON.
         * @function toJSON
         * @memberof warbase.ServerEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        ServerEvent.prototype.toJSON = function() {
            return ServerEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for ServerEvent
         * @function getTypeUrl
         * @memberof warbase.ServerEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        ServerEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.ServerEvent";
        };

        return ServerEvent;
    })();

    warbase.RespawnEvent = (function() {

        /**
         * Properties of a RespawnEvent.
         * @typedef {Object} warbase.RespawnEvent.$Properties
         * @property {number|null} [x] RespawnEvent x
         * @property {number|null} [y] RespawnEvent y
         * @property {number|null} [z] RespawnEvent z
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a RespawnEvent.
         * @memberof warbase
         * @interface IRespawnEvent
         * @augments warbase.RespawnEvent.$Properties
         * @deprecated Use warbase.RespawnEvent.$Properties instead.
         */

        /**
         * Shape of a RespawnEvent.
         * @typedef {warbase.RespawnEvent.$Properties} warbase.RespawnEvent.$Shape
         */

        /**
         * Constructs a new RespawnEvent.
         * @memberof warbase
         * @classdesc Represents a RespawnEvent.
         * @constructor
         * @param {warbase.RespawnEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var RespawnEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * RespawnEvent x.
         * @member {number} x
         * @memberof warbase.RespawnEvent
         * @instance
         */
        RespawnEvent.prototype.x = 0;

        /**
         * RespawnEvent y.
         * @member {number} y
         * @memberof warbase.RespawnEvent
         * @instance
         */
        RespawnEvent.prototype.y = 0;

        /**
         * RespawnEvent z.
         * @member {number} z
         * @memberof warbase.RespawnEvent
         * @instance
         */
        RespawnEvent.prototype.z = 0;

        /**
         * Creates a new RespawnEvent instance using the specified properties.
         * @function create
         * @memberof warbase.RespawnEvent
         * @static
         * @param {warbase.RespawnEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.RespawnEvent} RespawnEvent instance
         * @type {{
         *   (properties: warbase.RespawnEvent.$Shape): warbase.RespawnEvent & warbase.RespawnEvent.$Shape;
         *   (properties?: warbase.RespawnEvent.$Properties): warbase.RespawnEvent;
         * }}
         */
        RespawnEvent.create = function(properties) {
            return new RespawnEvent(properties);
        };

        /**
         * Encodes the specified RespawnEvent message. Does not implicitly {@link warbase.RespawnEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.RespawnEvent
         * @static
         * @param {warbase.RespawnEvent.$Properties} message RespawnEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        RespawnEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.x != null && $Object.hasOwnProperty.call(message, "x") && !$Object.is(message.x, 0))
                writer.uint32(/* id 1, wireType 5 =*/13).float(message.x);
            if (message.y != null && $Object.hasOwnProperty.call(message, "y") && !$Object.is(message.y, 0))
                writer.uint32(/* id 2, wireType 5 =*/21).float(message.y);
            if (message.z != null && $Object.hasOwnProperty.call(message, "z") && !$Object.is(message.z, 0))
                writer.uint32(/* id 3, wireType 5 =*/29).float(message.z);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified RespawnEvent message, length delimited. Does not implicitly {@link warbase.RespawnEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.RespawnEvent
         * @static
         * @param {warbase.RespawnEvent.$Properties} message RespawnEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        RespawnEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a RespawnEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.RespawnEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.RespawnEvent & warbase.RespawnEvent.$Shape} RespawnEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        RespawnEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.RespawnEvent(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.x = value;
                        else
                            delete message.x;
                        continue;
                    }
                case 2: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.y = value;
                        else
                            delete message.y;
                        continue;
                    }
                case 3: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.z = value;
                        else
                            delete message.z;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a RespawnEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.RespawnEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.RespawnEvent & warbase.RespawnEvent.$Shape} RespawnEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        RespawnEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a RespawnEvent message.
         * @function verify
         * @memberof warbase.RespawnEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        RespawnEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.x != null && $Object.hasOwnProperty.call(message, "x"))
                if (typeof message.x !== "number")
                    return "x: number expected";
            if (message.y != null && $Object.hasOwnProperty.call(message, "y"))
                if (typeof message.y !== "number")
                    return "y: number expected";
            if (message.z != null && $Object.hasOwnProperty.call(message, "z"))
                if (typeof message.z !== "number")
                    return "z: number expected";
            return null;
        };

        /**
         * Creates a RespawnEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.RespawnEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.RespawnEvent} RespawnEvent
         */
        RespawnEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.RespawnEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.RespawnEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.RespawnEvent();
            if (object.x != null)
                if (!$Object.is($Number(object.x), 0))
                    message.x = $Number(object.x);
            if (object.y != null)
                if (!$Object.is($Number(object.y), 0))
                    message.y = $Number(object.y);
            if (object.z != null)
                if (!$Object.is($Number(object.z), 0))
                    message.z = $Number(object.z);
            return message;
        };

        /**
         * Creates a plain object from a RespawnEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.RespawnEvent
         * @static
         * @param {warbase.RespawnEvent} message RespawnEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        RespawnEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults) {
                object.x = 0;
                object.y = 0;
                object.z = 0;
            }
            if (message.x != null && $Object.hasOwnProperty.call(message, "x"))
                object.x = options.json && !$isFinite(message.x) ? $String(message.x) : message.x;
            if (message.y != null && $Object.hasOwnProperty.call(message, "y"))
                object.y = options.json && !$isFinite(message.y) ? $String(message.y) : message.y;
            if (message.z != null && $Object.hasOwnProperty.call(message, "z"))
                object.z = options.json && !$isFinite(message.z) ? $String(message.z) : message.z;
            return object;
        };

        /**
         * Converts this RespawnEvent to JSON.
         * @function toJSON
         * @memberof warbase.RespawnEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        RespawnEvent.prototype.toJSON = function() {
            return RespawnEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for RespawnEvent
         * @function getTypeUrl
         * @memberof warbase.RespawnEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        RespawnEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.RespawnEvent";
        };

        return RespawnEvent;
    })();

    warbase.ServerFireEvent = (function() {

        /**
         * Properties of a ServerFireEvent.
         * @typedef {Object} warbase.ServerFireEvent.$Properties
         * @property {string|null} [shooterId] ServerFireEvent shooterId
         * @property {number|null} [originX] ServerFireEvent originX
         * @property {number|null} [originY] ServerFireEvent originY
         * @property {number|null} [originZ] ServerFireEvent originZ
         * @property {number|null} [hitX] ServerFireEvent hitX
         * @property {number|null} [hitY] ServerFireEvent hitY
         * @property {number|null} [hitZ] ServerFireEvent hitZ
         * @property {number|null} [normalX] ServerFireEvent normalX
         * @property {number|null} [normalY] ServerFireEvent normalY
         * @property {number|null} [normalZ] ServerFireEvent normalZ
         * @property {boolean|null} [hitWall] ServerFireEvent hitWall
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a ServerFireEvent.
         * @memberof warbase
         * @interface IServerFireEvent
         * @augments warbase.ServerFireEvent.$Properties
         * @deprecated Use warbase.ServerFireEvent.$Properties instead.
         */

        /**
         * Shape of a ServerFireEvent.
         * @typedef {warbase.ServerFireEvent.$Properties} warbase.ServerFireEvent.$Shape
         */

        /**
         * Constructs a new ServerFireEvent.
         * @memberof warbase
         * @classdesc Represents a ServerFireEvent.
         * @constructor
         * @param {warbase.ServerFireEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var ServerFireEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * ServerFireEvent shooterId.
         * @member {string} shooterId
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.shooterId = "";

        /**
         * ServerFireEvent originX.
         * @member {number} originX
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.originX = 0;

        /**
         * ServerFireEvent originY.
         * @member {number} originY
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.originY = 0;

        /**
         * ServerFireEvent originZ.
         * @member {number} originZ
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.originZ = 0;

        /**
         * ServerFireEvent hitX.
         * @member {number} hitX
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.hitX = 0;

        /**
         * ServerFireEvent hitY.
         * @member {number} hitY
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.hitY = 0;

        /**
         * ServerFireEvent hitZ.
         * @member {number} hitZ
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.hitZ = 0;

        /**
         * ServerFireEvent normalX.
         * @member {number} normalX
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.normalX = 0;

        /**
         * ServerFireEvent normalY.
         * @member {number} normalY
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.normalY = 0;

        /**
         * ServerFireEvent normalZ.
         * @member {number} normalZ
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.normalZ = 0;

        /**
         * ServerFireEvent hitWall.
         * @member {boolean} hitWall
         * @memberof warbase.ServerFireEvent
         * @instance
         */
        ServerFireEvent.prototype.hitWall = false;

        /**
         * Creates a new ServerFireEvent instance using the specified properties.
         * @function create
         * @memberof warbase.ServerFireEvent
         * @static
         * @param {warbase.ServerFireEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.ServerFireEvent} ServerFireEvent instance
         * @type {{
         *   (properties: warbase.ServerFireEvent.$Shape): warbase.ServerFireEvent & warbase.ServerFireEvent.$Shape;
         *   (properties?: warbase.ServerFireEvent.$Properties): warbase.ServerFireEvent;
         * }}
         */
        ServerFireEvent.create = function(properties) {
            return new ServerFireEvent(properties);
        };

        /**
         * Encodes the specified ServerFireEvent message. Does not implicitly {@link warbase.ServerFireEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.ServerFireEvent
         * @static
         * @param {warbase.ServerFireEvent.$Properties} message ServerFireEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ServerFireEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.shooterId != null && $Object.hasOwnProperty.call(message, "shooterId") && message.shooterId !== "")
                writer.uint32(/* id 1, wireType 2 =*/10).string(message.shooterId);
            if (message.originX != null && $Object.hasOwnProperty.call(message, "originX") && !$Object.is(message.originX, 0))
                writer.uint32(/* id 2, wireType 5 =*/21).float(message.originX);
            if (message.originY != null && $Object.hasOwnProperty.call(message, "originY") && !$Object.is(message.originY, 0))
                writer.uint32(/* id 3, wireType 5 =*/29).float(message.originY);
            if (message.originZ != null && $Object.hasOwnProperty.call(message, "originZ") && !$Object.is(message.originZ, 0))
                writer.uint32(/* id 4, wireType 5 =*/37).float(message.originZ);
            if (message.hitX != null && $Object.hasOwnProperty.call(message, "hitX") && !$Object.is(message.hitX, 0))
                writer.uint32(/* id 5, wireType 5 =*/45).float(message.hitX);
            if (message.hitY != null && $Object.hasOwnProperty.call(message, "hitY") && !$Object.is(message.hitY, 0))
                writer.uint32(/* id 6, wireType 5 =*/53).float(message.hitY);
            if (message.hitZ != null && $Object.hasOwnProperty.call(message, "hitZ") && !$Object.is(message.hitZ, 0))
                writer.uint32(/* id 7, wireType 5 =*/61).float(message.hitZ);
            if (message.normalX != null && $Object.hasOwnProperty.call(message, "normalX") && !$Object.is(message.normalX, 0))
                writer.uint32(/* id 8, wireType 5 =*/69).float(message.normalX);
            if (message.normalY != null && $Object.hasOwnProperty.call(message, "normalY") && !$Object.is(message.normalY, 0))
                writer.uint32(/* id 9, wireType 5 =*/77).float(message.normalY);
            if (message.normalZ != null && $Object.hasOwnProperty.call(message, "normalZ") && !$Object.is(message.normalZ, 0))
                writer.uint32(/* id 10, wireType 5 =*/85).float(message.normalZ);
            if (message.hitWall != null && $Object.hasOwnProperty.call(message, "hitWall") && message.hitWall !== false)
                writer.uint32(/* id 11, wireType 0 =*/88).bool(message.hitWall);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified ServerFireEvent message, length delimited. Does not implicitly {@link warbase.ServerFireEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.ServerFireEvent
         * @static
         * @param {warbase.ServerFireEvent.$Properties} message ServerFireEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ServerFireEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a ServerFireEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.ServerFireEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.ServerFireEvent & warbase.ServerFireEvent.$Shape} ServerFireEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ServerFireEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.ServerFireEvent(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.shooterId = value;
                        else
                            delete message.shooterId;
                        continue;
                    }
                case 2: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.originX = value;
                        else
                            delete message.originX;
                        continue;
                    }
                case 3: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.originY = value;
                        else
                            delete message.originY;
                        continue;
                    }
                case 4: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.originZ = value;
                        else
                            delete message.originZ;
                        continue;
                    }
                case 5: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.hitX = value;
                        else
                            delete message.hitX;
                        continue;
                    }
                case 6: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.hitY = value;
                        else
                            delete message.hitY;
                        continue;
                    }
                case 7: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.hitZ = value;
                        else
                            delete message.hitZ;
                        continue;
                    }
                case 8: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.normalX = value;
                        else
                            delete message.normalX;
                        continue;
                    }
                case 9: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.normalY = value;
                        else
                            delete message.normalY;
                        continue;
                    }
                case 10: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.normalZ = value;
                        else
                            delete message.normalZ;
                        continue;
                    }
                case 11: {
                        if (wireType !== 0)
                            break;
                        if (value = reader.bool())
                            message.hitWall = value;
                        else
                            delete message.hitWall;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a ServerFireEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.ServerFireEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.ServerFireEvent & warbase.ServerFireEvent.$Shape} ServerFireEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ServerFireEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a ServerFireEvent message.
         * @function verify
         * @memberof warbase.ServerFireEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        ServerFireEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.shooterId != null && $Object.hasOwnProperty.call(message, "shooterId"))
                if (!$util.isString(message.shooterId))
                    return "shooterId: string expected";
            if (message.originX != null && $Object.hasOwnProperty.call(message, "originX"))
                if (typeof message.originX !== "number")
                    return "originX: number expected";
            if (message.originY != null && $Object.hasOwnProperty.call(message, "originY"))
                if (typeof message.originY !== "number")
                    return "originY: number expected";
            if (message.originZ != null && $Object.hasOwnProperty.call(message, "originZ"))
                if (typeof message.originZ !== "number")
                    return "originZ: number expected";
            if (message.hitX != null && $Object.hasOwnProperty.call(message, "hitX"))
                if (typeof message.hitX !== "number")
                    return "hitX: number expected";
            if (message.hitY != null && $Object.hasOwnProperty.call(message, "hitY"))
                if (typeof message.hitY !== "number")
                    return "hitY: number expected";
            if (message.hitZ != null && $Object.hasOwnProperty.call(message, "hitZ"))
                if (typeof message.hitZ !== "number")
                    return "hitZ: number expected";
            if (message.normalX != null && $Object.hasOwnProperty.call(message, "normalX"))
                if (typeof message.normalX !== "number")
                    return "normalX: number expected";
            if (message.normalY != null && $Object.hasOwnProperty.call(message, "normalY"))
                if (typeof message.normalY !== "number")
                    return "normalY: number expected";
            if (message.normalZ != null && $Object.hasOwnProperty.call(message, "normalZ"))
                if (typeof message.normalZ !== "number")
                    return "normalZ: number expected";
            if (message.hitWall != null && $Object.hasOwnProperty.call(message, "hitWall"))
                if (typeof message.hitWall !== "boolean")
                    return "hitWall: boolean expected";
            return null;
        };

        /**
         * Creates a ServerFireEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.ServerFireEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.ServerFireEvent} ServerFireEvent
         */
        ServerFireEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.ServerFireEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.ServerFireEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.ServerFireEvent();
            if (object.shooterId != null)
                if (typeof object.shooterId !== "string" || object.shooterId.length)
                    message.shooterId = $String(object.shooterId);
            if (object.originX != null)
                if (!$Object.is($Number(object.originX), 0))
                    message.originX = $Number(object.originX);
            if (object.originY != null)
                if (!$Object.is($Number(object.originY), 0))
                    message.originY = $Number(object.originY);
            if (object.originZ != null)
                if (!$Object.is($Number(object.originZ), 0))
                    message.originZ = $Number(object.originZ);
            if (object.hitX != null)
                if (!$Object.is($Number(object.hitX), 0))
                    message.hitX = $Number(object.hitX);
            if (object.hitY != null)
                if (!$Object.is($Number(object.hitY), 0))
                    message.hitY = $Number(object.hitY);
            if (object.hitZ != null)
                if (!$Object.is($Number(object.hitZ), 0))
                    message.hitZ = $Number(object.hitZ);
            if (object.normalX != null)
                if (!$Object.is($Number(object.normalX), 0))
                    message.normalX = $Number(object.normalX);
            if (object.normalY != null)
                if (!$Object.is($Number(object.normalY), 0))
                    message.normalY = $Number(object.normalY);
            if (object.normalZ != null)
                if (!$Object.is($Number(object.normalZ), 0))
                    message.normalZ = $Number(object.normalZ);
            if (object.hitWall != null)
                if (object.hitWall)
                    message.hitWall = $Boolean(object.hitWall);
            return message;
        };

        /**
         * Creates a plain object from a ServerFireEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.ServerFireEvent
         * @static
         * @param {warbase.ServerFireEvent} message ServerFireEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        ServerFireEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults) {
                object.shooterId = "";
                object.originX = 0;
                object.originY = 0;
                object.originZ = 0;
                object.hitX = 0;
                object.hitY = 0;
                object.hitZ = 0;
                object.normalX = 0;
                object.normalY = 0;
                object.normalZ = 0;
                object.hitWall = false;
            }
            if (message.shooterId != null && $Object.hasOwnProperty.call(message, "shooterId"))
                object.shooterId = message.shooterId;
            if (message.originX != null && $Object.hasOwnProperty.call(message, "originX"))
                object.originX = options.json && !$isFinite(message.originX) ? $String(message.originX) : message.originX;
            if (message.originY != null && $Object.hasOwnProperty.call(message, "originY"))
                object.originY = options.json && !$isFinite(message.originY) ? $String(message.originY) : message.originY;
            if (message.originZ != null && $Object.hasOwnProperty.call(message, "originZ"))
                object.originZ = options.json && !$isFinite(message.originZ) ? $String(message.originZ) : message.originZ;
            if (message.hitX != null && $Object.hasOwnProperty.call(message, "hitX"))
                object.hitX = options.json && !$isFinite(message.hitX) ? $String(message.hitX) : message.hitX;
            if (message.hitY != null && $Object.hasOwnProperty.call(message, "hitY"))
                object.hitY = options.json && !$isFinite(message.hitY) ? $String(message.hitY) : message.hitY;
            if (message.hitZ != null && $Object.hasOwnProperty.call(message, "hitZ"))
                object.hitZ = options.json && !$isFinite(message.hitZ) ? $String(message.hitZ) : message.hitZ;
            if (message.normalX != null && $Object.hasOwnProperty.call(message, "normalX"))
                object.normalX = options.json && !$isFinite(message.normalX) ? $String(message.normalX) : message.normalX;
            if (message.normalY != null && $Object.hasOwnProperty.call(message, "normalY"))
                object.normalY = options.json && !$isFinite(message.normalY) ? $String(message.normalY) : message.normalY;
            if (message.normalZ != null && $Object.hasOwnProperty.call(message, "normalZ"))
                object.normalZ = options.json && !$isFinite(message.normalZ) ? $String(message.normalZ) : message.normalZ;
            if (message.hitWall != null && $Object.hasOwnProperty.call(message, "hitWall"))
                object.hitWall = message.hitWall;
            return object;
        };

        /**
         * Converts this ServerFireEvent to JSON.
         * @function toJSON
         * @memberof warbase.ServerFireEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        ServerFireEvent.prototype.toJSON = function() {
            return ServerFireEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for ServerFireEvent
         * @function getTypeUrl
         * @memberof warbase.ServerFireEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        ServerFireEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.ServerFireEvent";
        };

        return ServerFireEvent;
    })();

    warbase.HitConfirmedEvent = (function() {

        /**
         * Properties of a HitConfirmedEvent.
         * @typedef {Object} warbase.HitConfirmedEvent.$Properties
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a HitConfirmedEvent.
         * @memberof warbase
         * @interface IHitConfirmedEvent
         * @augments warbase.HitConfirmedEvent.$Properties
         * @deprecated Use warbase.HitConfirmedEvent.$Properties instead.
         */

        /**
         * Shape of a HitConfirmedEvent.
         * @typedef {warbase.HitConfirmedEvent.$Properties} warbase.HitConfirmedEvent.$Shape
         */

        /**
         * Constructs a new HitConfirmedEvent.
         * @memberof warbase
         * @classdesc Represents a HitConfirmedEvent.
         * @constructor
         * @param {warbase.HitConfirmedEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var HitConfirmedEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * Creates a new HitConfirmedEvent instance using the specified properties.
         * @function create
         * @memberof warbase.HitConfirmedEvent
         * @static
         * @param {warbase.HitConfirmedEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.HitConfirmedEvent} HitConfirmedEvent instance
         * @type {{
         *   (properties: warbase.HitConfirmedEvent.$Shape): warbase.HitConfirmedEvent & warbase.HitConfirmedEvent.$Shape;
         *   (properties?: warbase.HitConfirmedEvent.$Properties): warbase.HitConfirmedEvent;
         * }}
         */
        HitConfirmedEvent.create = function(properties) {
            return new HitConfirmedEvent(properties);
        };

        /**
         * Encodes the specified HitConfirmedEvent message. Does not implicitly {@link warbase.HitConfirmedEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.HitConfirmedEvent
         * @static
         * @param {warbase.HitConfirmedEvent.$Properties} message HitConfirmedEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        HitConfirmedEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified HitConfirmedEvent message, length delimited. Does not implicitly {@link warbase.HitConfirmedEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.HitConfirmedEvent
         * @static
         * @param {warbase.HitConfirmedEvent.$Properties} message HitConfirmedEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        HitConfirmedEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a HitConfirmedEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.HitConfirmedEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.HitConfirmedEvent & warbase.HitConfirmedEvent.$Shape} HitConfirmedEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        HitConfirmedEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.HitConfirmedEvent();
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                reader.skipType(tag & 7, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a HitConfirmedEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.HitConfirmedEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.HitConfirmedEvent & warbase.HitConfirmedEvent.$Shape} HitConfirmedEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        HitConfirmedEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a HitConfirmedEvent message.
         * @function verify
         * @memberof warbase.HitConfirmedEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        HitConfirmedEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            return null;
        };

        /**
         * Creates a HitConfirmedEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.HitConfirmedEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.HitConfirmedEvent} HitConfirmedEvent
         */
        HitConfirmedEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.HitConfirmedEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.HitConfirmedEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            return new $root.warbase.HitConfirmedEvent();
        };

        /**
         * Creates a plain object from a HitConfirmedEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.HitConfirmedEvent
         * @static
         * @param {warbase.HitConfirmedEvent} message HitConfirmedEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        HitConfirmedEvent.toObject = function () {
            return {};
        };

        /**
         * Converts this HitConfirmedEvent to JSON.
         * @function toJSON
         * @memberof warbase.HitConfirmedEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        HitConfirmedEvent.prototype.toJSON = function() {
            return HitConfirmedEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for HitConfirmedEvent
         * @function getTypeUrl
         * @memberof warbase.HitConfirmedEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        HitConfirmedEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.HitConfirmedEvent";
        };

        return HitConfirmedEvent;
    })();

    warbase.KillConfirmedEvent = (function() {

        /**
         * Properties of a KillConfirmedEvent.
         * @typedef {Object} warbase.KillConfirmedEvent.$Properties
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a KillConfirmedEvent.
         * @memberof warbase
         * @interface IKillConfirmedEvent
         * @augments warbase.KillConfirmedEvent.$Properties
         * @deprecated Use warbase.KillConfirmedEvent.$Properties instead.
         */

        /**
         * Shape of a KillConfirmedEvent.
         * @typedef {warbase.KillConfirmedEvent.$Properties} warbase.KillConfirmedEvent.$Shape
         */

        /**
         * Constructs a new KillConfirmedEvent.
         * @memberof warbase
         * @classdesc Represents a KillConfirmedEvent.
         * @constructor
         * @param {warbase.KillConfirmedEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var KillConfirmedEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * Creates a new KillConfirmedEvent instance using the specified properties.
         * @function create
         * @memberof warbase.KillConfirmedEvent
         * @static
         * @param {warbase.KillConfirmedEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.KillConfirmedEvent} KillConfirmedEvent instance
         * @type {{
         *   (properties: warbase.KillConfirmedEvent.$Shape): warbase.KillConfirmedEvent & warbase.KillConfirmedEvent.$Shape;
         *   (properties?: warbase.KillConfirmedEvent.$Properties): warbase.KillConfirmedEvent;
         * }}
         */
        KillConfirmedEvent.create = function(properties) {
            return new KillConfirmedEvent(properties);
        };

        /**
         * Encodes the specified KillConfirmedEvent message. Does not implicitly {@link warbase.KillConfirmedEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.KillConfirmedEvent
         * @static
         * @param {warbase.KillConfirmedEvent.$Properties} message KillConfirmedEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        KillConfirmedEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified KillConfirmedEvent message, length delimited. Does not implicitly {@link warbase.KillConfirmedEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.KillConfirmedEvent
         * @static
         * @param {warbase.KillConfirmedEvent.$Properties} message KillConfirmedEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        KillConfirmedEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a KillConfirmedEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.KillConfirmedEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.KillConfirmedEvent & warbase.KillConfirmedEvent.$Shape} KillConfirmedEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        KillConfirmedEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.KillConfirmedEvent();
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                reader.skipType(tag & 7, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a KillConfirmedEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.KillConfirmedEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.KillConfirmedEvent & warbase.KillConfirmedEvent.$Shape} KillConfirmedEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        KillConfirmedEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a KillConfirmedEvent message.
         * @function verify
         * @memberof warbase.KillConfirmedEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        KillConfirmedEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            return null;
        };

        /**
         * Creates a KillConfirmedEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.KillConfirmedEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.KillConfirmedEvent} KillConfirmedEvent
         */
        KillConfirmedEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.KillConfirmedEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.KillConfirmedEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            return new $root.warbase.KillConfirmedEvent();
        };

        /**
         * Creates a plain object from a KillConfirmedEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.KillConfirmedEvent
         * @static
         * @param {warbase.KillConfirmedEvent} message KillConfirmedEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        KillConfirmedEvent.toObject = function () {
            return {};
        };

        /**
         * Converts this KillConfirmedEvent to JSON.
         * @function toJSON
         * @memberof warbase.KillConfirmedEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        KillConfirmedEvent.prototype.toJSON = function() {
            return KillConfirmedEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for KillConfirmedEvent
         * @function getTypeUrl
         * @memberof warbase.KillConfirmedEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        KillConfirmedEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.KillConfirmedEvent";
        };

        return KillConfirmedEvent;
    })();

    warbase.ServerThrowGrenadeEvent = (function() {

        /**
         * Properties of a ServerThrowGrenadeEvent.
         * @typedef {Object} warbase.ServerThrowGrenadeEvent.$Properties
         * @property {string|null} [shooterId] ServerThrowGrenadeEvent shooterId
         * @property {number|null} [px] ServerThrowGrenadeEvent px
         * @property {number|null} [py] ServerThrowGrenadeEvent py
         * @property {number|null} [pz] ServerThrowGrenadeEvent pz
         * @property {number|null} [vx] ServerThrowGrenadeEvent vx
         * @property {number|null} [vy] ServerThrowGrenadeEvent vy
         * @property {number|null} [vz] ServerThrowGrenadeEvent vz
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */

        /**
         * Properties of a ServerThrowGrenadeEvent.
         * @memberof warbase
         * @interface IServerThrowGrenadeEvent
         * @augments warbase.ServerThrowGrenadeEvent.$Properties
         * @deprecated Use warbase.ServerThrowGrenadeEvent.$Properties instead.
         */

        /**
         * Shape of a ServerThrowGrenadeEvent.
         * @typedef {warbase.ServerThrowGrenadeEvent.$Properties} warbase.ServerThrowGrenadeEvent.$Shape
         */

        /**
         * Constructs a new ServerThrowGrenadeEvent.
         * @memberof warbase
         * @classdesc Represents a ServerThrowGrenadeEvent.
         * @constructor
         * @param {warbase.ServerThrowGrenadeEvent.$Properties=} [properties] Properties to set
         * @property {Array.<Uint8Array>} [$unknowns] Unknown fields preserved while decoding when enabled
         */
        var ServerThrowGrenadeEvent = function (properties) {
            if (properties)
                for (var keys = $Object.keys(properties), i = 0; i < keys.length; ++i)
                    if (properties[keys[i]] != null && keys[i] !== "__proto__")
                        this[keys[i]] = properties[keys[i]];
        };

        /**
         * ServerThrowGrenadeEvent shooterId.
         * @member {string} shooterId
         * @memberof warbase.ServerThrowGrenadeEvent
         * @instance
         */
        ServerThrowGrenadeEvent.prototype.shooterId = "";

        /**
         * ServerThrowGrenadeEvent px.
         * @member {number} px
         * @memberof warbase.ServerThrowGrenadeEvent
         * @instance
         */
        ServerThrowGrenadeEvent.prototype.px = 0;

        /**
         * ServerThrowGrenadeEvent py.
         * @member {number} py
         * @memberof warbase.ServerThrowGrenadeEvent
         * @instance
         */
        ServerThrowGrenadeEvent.prototype.py = 0;

        /**
         * ServerThrowGrenadeEvent pz.
         * @member {number} pz
         * @memberof warbase.ServerThrowGrenadeEvent
         * @instance
         */
        ServerThrowGrenadeEvent.prototype.pz = 0;

        /**
         * ServerThrowGrenadeEvent vx.
         * @member {number} vx
         * @memberof warbase.ServerThrowGrenadeEvent
         * @instance
         */
        ServerThrowGrenadeEvent.prototype.vx = 0;

        /**
         * ServerThrowGrenadeEvent vy.
         * @member {number} vy
         * @memberof warbase.ServerThrowGrenadeEvent
         * @instance
         */
        ServerThrowGrenadeEvent.prototype.vy = 0;

        /**
         * ServerThrowGrenadeEvent vz.
         * @member {number} vz
         * @memberof warbase.ServerThrowGrenadeEvent
         * @instance
         */
        ServerThrowGrenadeEvent.prototype.vz = 0;

        /**
         * Creates a new ServerThrowGrenadeEvent instance using the specified properties.
         * @function create
         * @memberof warbase.ServerThrowGrenadeEvent
         * @static
         * @param {warbase.ServerThrowGrenadeEvent.$Properties=} [properties] Properties to set
         * @returns {warbase.ServerThrowGrenadeEvent} ServerThrowGrenadeEvent instance
         * @type {{
         *   (properties: warbase.ServerThrowGrenadeEvent.$Shape): warbase.ServerThrowGrenadeEvent & warbase.ServerThrowGrenadeEvent.$Shape;
         *   (properties?: warbase.ServerThrowGrenadeEvent.$Properties): warbase.ServerThrowGrenadeEvent;
         * }}
         */
        ServerThrowGrenadeEvent.create = function(properties) {
            return new ServerThrowGrenadeEvent(properties);
        };

        /**
         * Encodes the specified ServerThrowGrenadeEvent message. Does not implicitly {@link warbase.ServerThrowGrenadeEvent.verify|verify} messages.
         * @function encode
         * @memberof warbase.ServerThrowGrenadeEvent
         * @static
         * @param {warbase.ServerThrowGrenadeEvent.$Properties} message ServerThrowGrenadeEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ServerThrowGrenadeEvent.encode = function (message, writer, _depth) {
            if (!writer)
                writer = $Writer.create();
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            if (message.shooterId != null && $Object.hasOwnProperty.call(message, "shooterId") && message.shooterId !== "")
                writer.uint32(/* id 1, wireType 2 =*/10).string(message.shooterId);
            if (message.px != null && $Object.hasOwnProperty.call(message, "px") && !$Object.is(message.px, 0))
                writer.uint32(/* id 2, wireType 5 =*/21).float(message.px);
            if (message.py != null && $Object.hasOwnProperty.call(message, "py") && !$Object.is(message.py, 0))
                writer.uint32(/* id 3, wireType 5 =*/29).float(message.py);
            if (message.pz != null && $Object.hasOwnProperty.call(message, "pz") && !$Object.is(message.pz, 0))
                writer.uint32(/* id 4, wireType 5 =*/37).float(message.pz);
            if (message.vx != null && $Object.hasOwnProperty.call(message, "vx") && !$Object.is(message.vx, 0))
                writer.uint32(/* id 5, wireType 5 =*/45).float(message.vx);
            if (message.vy != null && $Object.hasOwnProperty.call(message, "vy") && !$Object.is(message.vy, 0))
                writer.uint32(/* id 6, wireType 5 =*/53).float(message.vy);
            if (message.vz != null && $Object.hasOwnProperty.call(message, "vz") && !$Object.is(message.vz, 0))
                writer.uint32(/* id 7, wireType 5 =*/61).float(message.vz);
            if (message.$unknowns != null && $Object.hasOwnProperty.call(message, "$unknowns"))
                for (var i = 0; i < message.$unknowns.length; ++i)
                    writer.raw(message.$unknowns[i]);
            return writer;
        };

        /**
         * Encodes the specified ServerThrowGrenadeEvent message, length delimited. Does not implicitly {@link warbase.ServerThrowGrenadeEvent.verify|verify} messages.
         * @function encodeDelimited
         * @memberof warbase.ServerThrowGrenadeEvent
         * @static
         * @param {warbase.ServerThrowGrenadeEvent.$Properties} message ServerThrowGrenadeEvent message or plain object to encode
         * @param {$protobuf.Writer} [writer] Writer to encode to
         * @returns {$protobuf.Writer} Writer
         */
        ServerThrowGrenadeEvent.encodeDelimited = function(message, writer) {
            return this.encode(message, (writer || $Writer.create()).fork()).ldelim();
        };

        /**
         * Decodes a ServerThrowGrenadeEvent message from the specified reader or buffer.
         * @function decode
         * @memberof warbase.ServerThrowGrenadeEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @param {number} [length] Message length if known beforehand
         * @returns {warbase.ServerThrowGrenadeEvent & warbase.ServerThrowGrenadeEvent.$Shape} ServerThrowGrenadeEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ServerThrowGrenadeEvent.decode = function (reader, length, _end, _depth, _target) {
            if (!(reader instanceof $Reader))
                reader = $Reader.create(reader);
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $Reader.recursionLimit)
                throw $Error("max depth exceeded");
            var end = length === $undefined ? reader.len : reader.pos + length, message = _target || new $root.warbase.ServerThrowGrenadeEvent(), value;
            while (reader.pos < end) {
                var start = reader.pos;
                var tag = reader.tag();
                if (tag === _end) {
                    _end = $undefined;
                    break;
                }
                var wireType = tag & 7;
                switch (tag >>>= 3) {
                case 1: {
                        if (wireType !== 2)
                            break;
                        if ((value = reader.stringVerify()).length)
                            message.shooterId = value;
                        else
                            delete message.shooterId;
                        continue;
                    }
                case 2: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.px = value;
                        else
                            delete message.px;
                        continue;
                    }
                case 3: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.py = value;
                        else
                            delete message.py;
                        continue;
                    }
                case 4: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.pz = value;
                        else
                            delete message.pz;
                        continue;
                    }
                case 5: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.vx = value;
                        else
                            delete message.vx;
                        continue;
                    }
                case 6: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.vy = value;
                        else
                            delete message.vy;
                        continue;
                    }
                case 7: {
                        if (wireType !== 5)
                            break;
                        if (!$Object.is(value = reader.float(), 0))
                            message.vz = value;
                        else
                            delete message.vz;
                        continue;
                    }
                }
                reader.skipType(wireType, _depth, tag);
                if (!reader.discardUnknown) {
                    $util.makeProp(message, "$unknowns", false);
                    (message.$unknowns || (message.$unknowns = [])).push(reader.raw(start, reader.pos));
                }
            }
            if (_end !== $undefined)
                throw $Error("missing end group");
            return message;
        };

        /**
         * Decodes a ServerThrowGrenadeEvent message from the specified reader or buffer, length delimited.
         * @function decodeDelimited
         * @memberof warbase.ServerThrowGrenadeEvent
         * @static
         * @param {$protobuf.Reader|Uint8Array} reader Reader or buffer to decode from
         * @returns {warbase.ServerThrowGrenadeEvent & warbase.ServerThrowGrenadeEvent.$Shape} ServerThrowGrenadeEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        ServerThrowGrenadeEvent.decodeDelimited = function(reader) {
            if (!(reader instanceof $Reader))
                reader = new $Reader(reader);
            return this.decode(reader, reader.uint32());
        };

        /**
         * Verifies a ServerThrowGrenadeEvent message.
         * @function verify
         * @memberof warbase.ServerThrowGrenadeEvent
         * @static
         * @param {Object.<string,*>} message Plain object to verify
         * @returns {string|null} `null` if valid, otherwise the reason why it is not
         */
        ServerThrowGrenadeEvent.verify = function (message, _depth) {
            if (typeof message !== "object" || message === null)
                return "object expected";
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                return "max depth exceeded";
            if (message.shooterId != null && $Object.hasOwnProperty.call(message, "shooterId"))
                if (!$util.isString(message.shooterId))
                    return "shooterId: string expected";
            if (message.px != null && $Object.hasOwnProperty.call(message, "px"))
                if (typeof message.px !== "number")
                    return "px: number expected";
            if (message.py != null && $Object.hasOwnProperty.call(message, "py"))
                if (typeof message.py !== "number")
                    return "py: number expected";
            if (message.pz != null && $Object.hasOwnProperty.call(message, "pz"))
                if (typeof message.pz !== "number")
                    return "pz: number expected";
            if (message.vx != null && $Object.hasOwnProperty.call(message, "vx"))
                if (typeof message.vx !== "number")
                    return "vx: number expected";
            if (message.vy != null && $Object.hasOwnProperty.call(message, "vy"))
                if (typeof message.vy !== "number")
                    return "vy: number expected";
            if (message.vz != null && $Object.hasOwnProperty.call(message, "vz"))
                if (typeof message.vz !== "number")
                    return "vz: number expected";
            return null;
        };

        /**
         * Creates a ServerThrowGrenadeEvent message from a plain object. Also converts values to their respective internal types.
         * @function fromObject
         * @memberof warbase.ServerThrowGrenadeEvent
         * @static
         * @param {Object.<string,*>} object Plain object
         * @returns {warbase.ServerThrowGrenadeEvent} ServerThrowGrenadeEvent
         */
        ServerThrowGrenadeEvent.fromObject = function (object, _depth) {
            if (object instanceof $root.warbase.ServerThrowGrenadeEvent)
                return object;
            if (!$util.isObject(object))
                throw $TypeError(".warbase.ServerThrowGrenadeEvent: object expected");
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var message = new $root.warbase.ServerThrowGrenadeEvent();
            if (object.shooterId != null)
                if (typeof object.shooterId !== "string" || object.shooterId.length)
                    message.shooterId = $String(object.shooterId);
            if (object.px != null)
                if (!$Object.is($Number(object.px), 0))
                    message.px = $Number(object.px);
            if (object.py != null)
                if (!$Object.is($Number(object.py), 0))
                    message.py = $Number(object.py);
            if (object.pz != null)
                if (!$Object.is($Number(object.pz), 0))
                    message.pz = $Number(object.pz);
            if (object.vx != null)
                if (!$Object.is($Number(object.vx), 0))
                    message.vx = $Number(object.vx);
            if (object.vy != null)
                if (!$Object.is($Number(object.vy), 0))
                    message.vy = $Number(object.vy);
            if (object.vz != null)
                if (!$Object.is($Number(object.vz), 0))
                    message.vz = $Number(object.vz);
            return message;
        };

        /**
         * Creates a plain object from a ServerThrowGrenadeEvent message. Also converts values to other types if specified.
         * @function toObject
         * @memberof warbase.ServerThrowGrenadeEvent
         * @static
         * @param {warbase.ServerThrowGrenadeEvent} message ServerThrowGrenadeEvent
         * @param {$protobuf.IConversionOptions} [options] Conversion options
         * @returns {Object.<string,*>} Plain object
         */
        ServerThrowGrenadeEvent.toObject = function (message, options, _depth) {
            if (!options)
                options = {};
            if (_depth === $undefined)
                _depth = 0;
            if (_depth > $util.recursionLimit)
                throw $Error("max depth exceeded");
            var object = {};
            if (options.defaults) {
                object.shooterId = "";
                object.px = 0;
                object.py = 0;
                object.pz = 0;
                object.vx = 0;
                object.vy = 0;
                object.vz = 0;
            }
            if (message.shooterId != null && $Object.hasOwnProperty.call(message, "shooterId"))
                object.shooterId = message.shooterId;
            if (message.px != null && $Object.hasOwnProperty.call(message, "px"))
                object.px = options.json && !$isFinite(message.px) ? $String(message.px) : message.px;
            if (message.py != null && $Object.hasOwnProperty.call(message, "py"))
                object.py = options.json && !$isFinite(message.py) ? $String(message.py) : message.py;
            if (message.pz != null && $Object.hasOwnProperty.call(message, "pz"))
                object.pz = options.json && !$isFinite(message.pz) ? $String(message.pz) : message.pz;
            if (message.vx != null && $Object.hasOwnProperty.call(message, "vx"))
                object.vx = options.json && !$isFinite(message.vx) ? $String(message.vx) : message.vx;
            if (message.vy != null && $Object.hasOwnProperty.call(message, "vy"))
                object.vy = options.json && !$isFinite(message.vy) ? $String(message.vy) : message.vy;
            if (message.vz != null && $Object.hasOwnProperty.call(message, "vz"))
                object.vz = options.json && !$isFinite(message.vz) ? $String(message.vz) : message.vz;
            return object;
        };

        /**
         * Converts this ServerThrowGrenadeEvent to JSON.
         * @function toJSON
         * @memberof warbase.ServerThrowGrenadeEvent
         * @instance
         * @returns {Object.<string,*>} JSON object
         */
        ServerThrowGrenadeEvent.prototype.toJSON = function() {
            return ServerThrowGrenadeEvent.toObject(this, $protobuf.util.toJSONOptions);
        };

        /**
         * Gets the type url for ServerThrowGrenadeEvent
         * @function getTypeUrl
         * @memberof warbase.ServerThrowGrenadeEvent
         * @static
         * @param {string} [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns {string} The type url
         */
        ServerThrowGrenadeEvent.getTypeUrl = function(prefix) {
            if (prefix === $undefined)
                prefix = "type.googleapis.com";
            return prefix + "/warbase.ServerThrowGrenadeEvent";
        };

        return ServerThrowGrenadeEvent;
    })();

    return warbase;
})();

module.exports = $root;
