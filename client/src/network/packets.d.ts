import * as $protobuf from "protobufjs";
import Long = require("long");

/** Namespace warbase. */
export namespace warbase {

    /**
     * Properties of a ClientEvent.
     * @deprecated Use warbase.ClientEvent.$Properties instead.
     */
    interface IClientEvent extends warbase.ClientEvent.$Properties {
    }

    /** Represents a ClientEvent. */
    class ClientEvent {

        /**
         * Constructs a new ClientEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.ClientEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** ClientEvent stateUpdate. */
        stateUpdate?: (warbase.PlayerStateUpdate.$Properties|null);

        /** ClientEvent hit. */
        hit?: (warbase.HitEvent.$Properties|null);

        /** ClientEvent fire. */
        fire?: (warbase.FireEvent.$Properties|null);

        /** ClientEvent reload. */
        reload?: (warbase.ReloadEvent.$Properties|null);

        /** ClientEvent switchWeapon. */
        switchWeapon?: (warbase.SwitchWeaponEvent.$Properties|null);

        /** ClientEvent respawnRequest. */
        respawnRequest?: (warbase.RespawnRequestEvent.$Properties|null);

        /** ClientEvent throwGrenade. */
        throwGrenade?: (warbase.ThrowGrenadeEvent.$Properties|null);

        /** ClientEvent ping. */
        ping?: (warbase.PingEvent.$Properties|null);

        /** ClientEvent event. */
        event?: ("stateUpdate"|"hit"|"fire"|"reload"|"switchWeapon"|"respawnRequest"|"throwGrenade"|"ping");

        /**
         * Creates a new ClientEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns ClientEvent instance
         */
        static create(properties: warbase.ClientEvent.$Shape): warbase.ClientEvent & warbase.ClientEvent.$Shape;
        static create(properties?: warbase.ClientEvent.$Properties): warbase.ClientEvent;

        /**
         * Encodes the specified ClientEvent message. Does not implicitly {@link warbase.ClientEvent.verify|verify} messages.
         * @param message ClientEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.ClientEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified ClientEvent message, length delimited. Does not implicitly {@link warbase.ClientEvent.verify|verify} messages.
         * @param message ClientEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.ClientEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a ClientEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.ClientEvent & warbase.ClientEvent.$Shape} ClientEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.ClientEvent & warbase.ClientEvent.$Shape;

        /**
         * Decodes a ClientEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.ClientEvent & warbase.ClientEvent.$Shape} ClientEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.ClientEvent & warbase.ClientEvent.$Shape;

        /**
         * Verifies a ClientEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a ClientEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns ClientEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.ClientEvent;

        /**
         * Creates a plain object from a ClientEvent message. Also converts values to other types if specified.
         * @param message ClientEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.ClientEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this ClientEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for ClientEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace ClientEvent {

        /** Properties of a ClientEvent. */
        interface $Properties {

            /** ClientEvent stateUpdate */
            stateUpdate?: (warbase.PlayerStateUpdate.$Properties|null);

            /** ClientEvent hit */
            hit?: (warbase.HitEvent.$Properties|null);

            /** ClientEvent fire */
            fire?: (warbase.FireEvent.$Properties|null);

            /** ClientEvent reload */
            reload?: (warbase.ReloadEvent.$Properties|null);

            /** ClientEvent switchWeapon */
            switchWeapon?: (warbase.SwitchWeaponEvent.$Properties|null);

            /** ClientEvent respawnRequest */
            respawnRequest?: (warbase.RespawnRequestEvent.$Properties|null);

            /** ClientEvent throwGrenade */
            throwGrenade?: (warbase.ThrowGrenadeEvent.$Properties|null);

            /** ClientEvent ping */
            ping?: (warbase.PingEvent.$Properties|null);

            /** ClientEvent event */
            event?: ("stateUpdate"|"hit"|"fire"|"reload"|"switchWeapon"|"respawnRequest"|"throwGrenade"|"ping");

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Narrowed shape of a ClientEvent. */
        type $Shape = {
          stateUpdate?: warbase.PlayerStateUpdate.$Shape|null;
          hit?: warbase.HitEvent.$Shape|null;
          fire?: warbase.FireEvent.$Shape|null;
          reload?: warbase.ReloadEvent.$Shape|null;
          switchWeapon?: warbase.SwitchWeaponEvent.$Shape|null;
          respawnRequest?: warbase.RespawnRequestEvent.$Shape|null;
          throwGrenade?: warbase.ThrowGrenadeEvent.$Shape|null;
          ping?: warbase.PingEvent.$Shape|null;
          $unknowns?: Uint8Array[];
        } & (
          ({ event?: undefined; stateUpdate?: null; hit?: null; fire?: null; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "stateUpdate"; stateUpdate: warbase.PlayerStateUpdate.$Shape; hit?: null; fire?: null; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "hit"; stateUpdate?: null; hit: warbase.HitEvent.$Shape; fire?: null; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "fire"; stateUpdate?: null; hit?: null; fire: warbase.FireEvent.$Shape; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "reload"; stateUpdate?: null; hit?: null; fire?: null; reload: warbase.ReloadEvent.$Shape; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "switchWeapon"; stateUpdate?: null; hit?: null; fire?: null; reload?: null; switchWeapon: warbase.SwitchWeaponEvent.$Shape; respawnRequest?: null; throwGrenade?: null; ping?: null }|{ event?: "respawnRequest"; stateUpdate?: null; hit?: null; fire?: null; reload?: null; switchWeapon?: null; respawnRequest: warbase.RespawnRequestEvent.$Shape; throwGrenade?: null; ping?: null }|{ event?: "throwGrenade"; stateUpdate?: null; hit?: null; fire?: null; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade: warbase.ThrowGrenadeEvent.$Shape; ping?: null }|{ event?: "ping"; stateUpdate?: null; hit?: null; fire?: null; reload?: null; switchWeapon?: null; respawnRequest?: null; throwGrenade?: null; ping: warbase.PingEvent.$Shape })
        );
    }

    /**
     * Properties of a PlayerStateUpdate.
     * @deprecated Use warbase.PlayerStateUpdate.$Properties instead.
     */
    interface IPlayerStateUpdate extends warbase.PlayerStateUpdate.$Properties {
    }

    /** Represents a PlayerStateUpdate. */
    class PlayerStateUpdate {

        /**
         * Constructs a new PlayerStateUpdate.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.PlayerStateUpdate.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** PlayerStateUpdate x. */
        x: number;

        /** PlayerStateUpdate y. */
        y: number;

        /** PlayerStateUpdate z. */
        z: number;

        /** PlayerStateUpdate rx. */
        rx: number;

        /** PlayerStateUpdate ry. */
        ry: number;

        /** PlayerStateUpdate rz. */
        rz: number;

        /** PlayerStateUpdate rw. */
        rw: number;

        /** PlayerStateUpdate animation. */
        animation: string;

        /** PlayerStateUpdate platformId. */
        platformId: string;

        /** PlayerStateUpdate ping. */
        ping: number;

        /** PlayerStateUpdate weaponId. */
        weaponId: string;

        /**
         * Creates a new PlayerStateUpdate instance using the specified properties.
         * @param [properties] Properties to set
         * @returns PlayerStateUpdate instance
         */
        static create(properties: warbase.PlayerStateUpdate.$Shape): warbase.PlayerStateUpdate & warbase.PlayerStateUpdate.$Shape;
        static create(properties?: warbase.PlayerStateUpdate.$Properties): warbase.PlayerStateUpdate;

        /**
         * Encodes the specified PlayerStateUpdate message. Does not implicitly {@link warbase.PlayerStateUpdate.verify|verify} messages.
         * @param message PlayerStateUpdate message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.PlayerStateUpdate.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified PlayerStateUpdate message, length delimited. Does not implicitly {@link warbase.PlayerStateUpdate.verify|verify} messages.
         * @param message PlayerStateUpdate message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.PlayerStateUpdate.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a PlayerStateUpdate message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.PlayerStateUpdate & warbase.PlayerStateUpdate.$Shape} PlayerStateUpdate
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.PlayerStateUpdate & warbase.PlayerStateUpdate.$Shape;

        /**
         * Decodes a PlayerStateUpdate message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.PlayerStateUpdate & warbase.PlayerStateUpdate.$Shape} PlayerStateUpdate
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.PlayerStateUpdate & warbase.PlayerStateUpdate.$Shape;

        /**
         * Verifies a PlayerStateUpdate message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a PlayerStateUpdate message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns PlayerStateUpdate
         */
        static fromObject(object: { [k: string]: any }): warbase.PlayerStateUpdate;

        /**
         * Creates a plain object from a PlayerStateUpdate message. Also converts values to other types if specified.
         * @param message PlayerStateUpdate
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.PlayerStateUpdate, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this PlayerStateUpdate to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for PlayerStateUpdate
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace PlayerStateUpdate {

        /** Properties of a PlayerStateUpdate. */
        interface $Properties {

            /** PlayerStateUpdate x */
            x?: (number|null);

            /** PlayerStateUpdate y */
            y?: (number|null);

            /** PlayerStateUpdate z */
            z?: (number|null);

            /** PlayerStateUpdate rx */
            rx?: (number|null);

            /** PlayerStateUpdate ry */
            ry?: (number|null);

            /** PlayerStateUpdate rz */
            rz?: (number|null);

            /** PlayerStateUpdate rw */
            rw?: (number|null);

            /** PlayerStateUpdate animation */
            animation?: (string|null);

            /** PlayerStateUpdate platformId */
            platformId?: (string|null);

            /** PlayerStateUpdate ping */
            ping?: (number|null);

            /** PlayerStateUpdate weaponId */
            weaponId?: (string|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a PlayerStateUpdate. */
        type $Shape = warbase.PlayerStateUpdate.$Properties;
    }

    /**
     * Properties of a HitEvent.
     * @deprecated Use warbase.HitEvent.$Properties instead.
     */
    interface IHitEvent extends warbase.HitEvent.$Properties {
    }

    /** Represents a HitEvent. */
    class HitEvent {

        /**
         * Constructs a new HitEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.HitEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** HitEvent targetId. */
        targetId: string;

        /** HitEvent damage. */
        damage: number;

        /**
         * Creates a new HitEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns HitEvent instance
         */
        static create(properties: warbase.HitEvent.$Shape): warbase.HitEvent & warbase.HitEvent.$Shape;
        static create(properties?: warbase.HitEvent.$Properties): warbase.HitEvent;

        /**
         * Encodes the specified HitEvent message. Does not implicitly {@link warbase.HitEvent.verify|verify} messages.
         * @param message HitEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.HitEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified HitEvent message, length delimited. Does not implicitly {@link warbase.HitEvent.verify|verify} messages.
         * @param message HitEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.HitEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a HitEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.HitEvent & warbase.HitEvent.$Shape} HitEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.HitEvent & warbase.HitEvent.$Shape;

        /**
         * Decodes a HitEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.HitEvent & warbase.HitEvent.$Shape} HitEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.HitEvent & warbase.HitEvent.$Shape;

        /**
         * Verifies a HitEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a HitEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns HitEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.HitEvent;

        /**
         * Creates a plain object from a HitEvent message. Also converts values to other types if specified.
         * @param message HitEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.HitEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this HitEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for HitEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace HitEvent {

        /** Properties of a HitEvent. */
        interface $Properties {

            /** HitEvent targetId */
            targetId?: (string|null);

            /** HitEvent damage */
            damage?: (number|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a HitEvent. */
        type $Shape = warbase.HitEvent.$Properties;
    }

    /**
     * Properties of a FireEvent.
     * @deprecated Use warbase.FireEvent.$Properties instead.
     */
    interface IFireEvent extends warbase.FireEvent.$Properties {
    }

    /** Represents a FireEvent. */
    class FireEvent {

        /**
         * Constructs a new FireEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.FireEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** FireEvent originX. */
        originX: number;

        /** FireEvent originY. */
        originY: number;

        /** FireEvent originZ. */
        originZ: number;

        /** FireEvent hitX. */
        hitX: number;

        /** FireEvent hitY. */
        hitY: number;

        /** FireEvent hitZ. */
        hitZ: number;

        /** FireEvent normalX. */
        normalX: number;

        /** FireEvent normalY. */
        normalY: number;

        /** FireEvent normalZ. */
        normalZ: number;

        /** FireEvent hitWall. */
        hitWall: boolean;

        /**
         * Creates a new FireEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns FireEvent instance
         */
        static create(properties: warbase.FireEvent.$Shape): warbase.FireEvent & warbase.FireEvent.$Shape;
        static create(properties?: warbase.FireEvent.$Properties): warbase.FireEvent;

        /**
         * Encodes the specified FireEvent message. Does not implicitly {@link warbase.FireEvent.verify|verify} messages.
         * @param message FireEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.FireEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified FireEvent message, length delimited. Does not implicitly {@link warbase.FireEvent.verify|verify} messages.
         * @param message FireEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.FireEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a FireEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.FireEvent & warbase.FireEvent.$Shape} FireEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.FireEvent & warbase.FireEvent.$Shape;

        /**
         * Decodes a FireEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.FireEvent & warbase.FireEvent.$Shape} FireEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.FireEvent & warbase.FireEvent.$Shape;

        /**
         * Verifies a FireEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a FireEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns FireEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.FireEvent;

        /**
         * Creates a plain object from a FireEvent message. Also converts values to other types if specified.
         * @param message FireEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.FireEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this FireEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for FireEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace FireEvent {

        /** Properties of a FireEvent. */
        interface $Properties {

            /** FireEvent originX */
            originX?: (number|null);

            /** FireEvent originY */
            originY?: (number|null);

            /** FireEvent originZ */
            originZ?: (number|null);

            /** FireEvent hitX */
            hitX?: (number|null);

            /** FireEvent hitY */
            hitY?: (number|null);

            /** FireEvent hitZ */
            hitZ?: (number|null);

            /** FireEvent normalX */
            normalX?: (number|null);

            /** FireEvent normalY */
            normalY?: (number|null);

            /** FireEvent normalZ */
            normalZ?: (number|null);

            /** FireEvent hitWall */
            hitWall?: (boolean|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a FireEvent. */
        type $Shape = warbase.FireEvent.$Properties;
    }

    /**
     * Properties of a ReloadEvent.
     * @deprecated Use warbase.ReloadEvent.$Properties instead.
     */
    interface IReloadEvent extends warbase.ReloadEvent.$Properties {
    }

    /** Represents a ReloadEvent. */
    class ReloadEvent {

        /**
         * Constructs a new ReloadEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.ReloadEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /**
         * Creates a new ReloadEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns ReloadEvent instance
         */
        static create(properties: warbase.ReloadEvent.$Shape): warbase.ReloadEvent & warbase.ReloadEvent.$Shape;
        static create(properties?: warbase.ReloadEvent.$Properties): warbase.ReloadEvent;

        /**
         * Encodes the specified ReloadEvent message. Does not implicitly {@link warbase.ReloadEvent.verify|verify} messages.
         * @param message ReloadEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.ReloadEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified ReloadEvent message, length delimited. Does not implicitly {@link warbase.ReloadEvent.verify|verify} messages.
         * @param message ReloadEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.ReloadEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a ReloadEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.ReloadEvent & warbase.ReloadEvent.$Shape} ReloadEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.ReloadEvent & warbase.ReloadEvent.$Shape;

        /**
         * Decodes a ReloadEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.ReloadEvent & warbase.ReloadEvent.$Shape} ReloadEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.ReloadEvent & warbase.ReloadEvent.$Shape;

        /**
         * Verifies a ReloadEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a ReloadEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns ReloadEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.ReloadEvent;

        /**
         * Creates a plain object from a ReloadEvent message. Also converts values to other types if specified.
         * @param message ReloadEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.ReloadEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this ReloadEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for ReloadEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace ReloadEvent {

        /** Properties of a ReloadEvent. */
        interface $Properties {

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a ReloadEvent. */
        type $Shape = warbase.ReloadEvent.$Properties;
    }

    /**
     * Properties of a SwitchWeaponEvent.
     * @deprecated Use warbase.SwitchWeaponEvent.$Properties instead.
     */
    interface ISwitchWeaponEvent extends warbase.SwitchWeaponEvent.$Properties {
    }

    /** Represents a SwitchWeaponEvent. */
    class SwitchWeaponEvent {

        /**
         * Constructs a new SwitchWeaponEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.SwitchWeaponEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** SwitchWeaponEvent weaponId. */
        weaponId: string;

        /**
         * Creates a new SwitchWeaponEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns SwitchWeaponEvent instance
         */
        static create(properties: warbase.SwitchWeaponEvent.$Shape): warbase.SwitchWeaponEvent & warbase.SwitchWeaponEvent.$Shape;
        static create(properties?: warbase.SwitchWeaponEvent.$Properties): warbase.SwitchWeaponEvent;

        /**
         * Encodes the specified SwitchWeaponEvent message. Does not implicitly {@link warbase.SwitchWeaponEvent.verify|verify} messages.
         * @param message SwitchWeaponEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.SwitchWeaponEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified SwitchWeaponEvent message, length delimited. Does not implicitly {@link warbase.SwitchWeaponEvent.verify|verify} messages.
         * @param message SwitchWeaponEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.SwitchWeaponEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a SwitchWeaponEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.SwitchWeaponEvent & warbase.SwitchWeaponEvent.$Shape} SwitchWeaponEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.SwitchWeaponEvent & warbase.SwitchWeaponEvent.$Shape;

        /**
         * Decodes a SwitchWeaponEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.SwitchWeaponEvent & warbase.SwitchWeaponEvent.$Shape} SwitchWeaponEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.SwitchWeaponEvent & warbase.SwitchWeaponEvent.$Shape;

        /**
         * Verifies a SwitchWeaponEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a SwitchWeaponEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns SwitchWeaponEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.SwitchWeaponEvent;

        /**
         * Creates a plain object from a SwitchWeaponEvent message. Also converts values to other types if specified.
         * @param message SwitchWeaponEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.SwitchWeaponEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this SwitchWeaponEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for SwitchWeaponEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace SwitchWeaponEvent {

        /** Properties of a SwitchWeaponEvent. */
        interface $Properties {

            /** SwitchWeaponEvent weaponId */
            weaponId?: (string|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a SwitchWeaponEvent. */
        type $Shape = warbase.SwitchWeaponEvent.$Properties;
    }

    /**
     * Properties of a RespawnRequestEvent.
     * @deprecated Use warbase.RespawnRequestEvent.$Properties instead.
     */
    interface IRespawnRequestEvent extends warbase.RespawnRequestEvent.$Properties {
    }

    /** Represents a RespawnRequestEvent. */
    class RespawnRequestEvent {

        /**
         * Constructs a new RespawnRequestEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.RespawnRequestEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /**
         * Creates a new RespawnRequestEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns RespawnRequestEvent instance
         */
        static create(properties: warbase.RespawnRequestEvent.$Shape): warbase.RespawnRequestEvent & warbase.RespawnRequestEvent.$Shape;
        static create(properties?: warbase.RespawnRequestEvent.$Properties): warbase.RespawnRequestEvent;

        /**
         * Encodes the specified RespawnRequestEvent message. Does not implicitly {@link warbase.RespawnRequestEvent.verify|verify} messages.
         * @param message RespawnRequestEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.RespawnRequestEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified RespawnRequestEvent message, length delimited. Does not implicitly {@link warbase.RespawnRequestEvent.verify|verify} messages.
         * @param message RespawnRequestEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.RespawnRequestEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a RespawnRequestEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.RespawnRequestEvent & warbase.RespawnRequestEvent.$Shape} RespawnRequestEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.RespawnRequestEvent & warbase.RespawnRequestEvent.$Shape;

        /**
         * Decodes a RespawnRequestEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.RespawnRequestEvent & warbase.RespawnRequestEvent.$Shape} RespawnRequestEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.RespawnRequestEvent & warbase.RespawnRequestEvent.$Shape;

        /**
         * Verifies a RespawnRequestEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a RespawnRequestEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns RespawnRequestEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.RespawnRequestEvent;

        /**
         * Creates a plain object from a RespawnRequestEvent message. Also converts values to other types if specified.
         * @param message RespawnRequestEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.RespawnRequestEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this RespawnRequestEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for RespawnRequestEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace RespawnRequestEvent {

        /** Properties of a RespawnRequestEvent. */
        interface $Properties {

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a RespawnRequestEvent. */
        type $Shape = warbase.RespawnRequestEvent.$Properties;
    }

    /**
     * Properties of a ThrowGrenadeEvent.
     * @deprecated Use warbase.ThrowGrenadeEvent.$Properties instead.
     */
    interface IThrowGrenadeEvent extends warbase.ThrowGrenadeEvent.$Properties {
    }

    /** Represents a ThrowGrenadeEvent. */
    class ThrowGrenadeEvent {

        /**
         * Constructs a new ThrowGrenadeEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.ThrowGrenadeEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** ThrowGrenadeEvent px. */
        px: number;

        /** ThrowGrenadeEvent py. */
        py: number;

        /** ThrowGrenadeEvent pz. */
        pz: number;

        /** ThrowGrenadeEvent vx. */
        vx: number;

        /** ThrowGrenadeEvent vy. */
        vy: number;

        /** ThrowGrenadeEvent vz. */
        vz: number;

        /**
         * Creates a new ThrowGrenadeEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns ThrowGrenadeEvent instance
         */
        static create(properties: warbase.ThrowGrenadeEvent.$Shape): warbase.ThrowGrenadeEvent & warbase.ThrowGrenadeEvent.$Shape;
        static create(properties?: warbase.ThrowGrenadeEvent.$Properties): warbase.ThrowGrenadeEvent;

        /**
         * Encodes the specified ThrowGrenadeEvent message. Does not implicitly {@link warbase.ThrowGrenadeEvent.verify|verify} messages.
         * @param message ThrowGrenadeEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.ThrowGrenadeEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified ThrowGrenadeEvent message, length delimited. Does not implicitly {@link warbase.ThrowGrenadeEvent.verify|verify} messages.
         * @param message ThrowGrenadeEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.ThrowGrenadeEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a ThrowGrenadeEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.ThrowGrenadeEvent & warbase.ThrowGrenadeEvent.$Shape} ThrowGrenadeEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.ThrowGrenadeEvent & warbase.ThrowGrenadeEvent.$Shape;

        /**
         * Decodes a ThrowGrenadeEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.ThrowGrenadeEvent & warbase.ThrowGrenadeEvent.$Shape} ThrowGrenadeEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.ThrowGrenadeEvent & warbase.ThrowGrenadeEvent.$Shape;

        /**
         * Verifies a ThrowGrenadeEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a ThrowGrenadeEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns ThrowGrenadeEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.ThrowGrenadeEvent;

        /**
         * Creates a plain object from a ThrowGrenadeEvent message. Also converts values to other types if specified.
         * @param message ThrowGrenadeEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.ThrowGrenadeEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this ThrowGrenadeEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for ThrowGrenadeEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace ThrowGrenadeEvent {

        /** Properties of a ThrowGrenadeEvent. */
        interface $Properties {

            /** ThrowGrenadeEvent px */
            px?: (number|null);

            /** ThrowGrenadeEvent py */
            py?: (number|null);

            /** ThrowGrenadeEvent pz */
            pz?: (number|null);

            /** ThrowGrenadeEvent vx */
            vx?: (number|null);

            /** ThrowGrenadeEvent vy */
            vy?: (number|null);

            /** ThrowGrenadeEvent vz */
            vz?: (number|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a ThrowGrenadeEvent. */
        type $Shape = warbase.ThrowGrenadeEvent.$Properties;
    }

    /**
     * Properties of a ServerPongEvent.
     * @deprecated Use warbase.ServerPongEvent.$Properties instead.
     */
    interface IServerPongEvent extends warbase.ServerPongEvent.$Properties {
    }

    /** Represents a ServerPongEvent. */
    class ServerPongEvent {

        /**
         * Constructs a new ServerPongEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.ServerPongEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** ServerPongEvent clientTime. */
        clientTime: (number|Long);

        /**
         * Creates a new ServerPongEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns ServerPongEvent instance
         */
        static create(properties: warbase.ServerPongEvent.$Shape): warbase.ServerPongEvent & warbase.ServerPongEvent.$Shape;
        static create(properties?: warbase.ServerPongEvent.$Properties): warbase.ServerPongEvent;

        /**
         * Encodes the specified ServerPongEvent message. Does not implicitly {@link warbase.ServerPongEvent.verify|verify} messages.
         * @param message ServerPongEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.ServerPongEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified ServerPongEvent message, length delimited. Does not implicitly {@link warbase.ServerPongEvent.verify|verify} messages.
         * @param message ServerPongEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.ServerPongEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a ServerPongEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.ServerPongEvent & warbase.ServerPongEvent.$Shape} ServerPongEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.ServerPongEvent & warbase.ServerPongEvent.$Shape;

        /**
         * Decodes a ServerPongEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.ServerPongEvent & warbase.ServerPongEvent.$Shape} ServerPongEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.ServerPongEvent & warbase.ServerPongEvent.$Shape;

        /**
         * Verifies a ServerPongEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a ServerPongEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns ServerPongEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.ServerPongEvent;

        /**
         * Creates a plain object from a ServerPongEvent message. Also converts values to other types if specified.
         * @param message ServerPongEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.ServerPongEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this ServerPongEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for ServerPongEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace ServerPongEvent {

        /** Properties of a ServerPongEvent. */
        interface $Properties {

            /** ServerPongEvent clientTime */
            clientTime?: (number|Long|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a ServerPongEvent. */
        type $Shape = warbase.ServerPongEvent.$Properties;
    }

    /**
     * Properties of a PingEvent.
     * @deprecated Use warbase.PingEvent.$Properties instead.
     */
    interface IPingEvent extends warbase.PingEvent.$Properties {
    }

    /** Represents a PingEvent. */
    class PingEvent {

        /**
         * Constructs a new PingEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.PingEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** PingEvent clientTime. */
        clientTime: (number|Long);

        /**
         * Creates a new PingEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns PingEvent instance
         */
        static create(properties: warbase.PingEvent.$Shape): warbase.PingEvent & warbase.PingEvent.$Shape;
        static create(properties?: warbase.PingEvent.$Properties): warbase.PingEvent;

        /**
         * Encodes the specified PingEvent message. Does not implicitly {@link warbase.PingEvent.verify|verify} messages.
         * @param message PingEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.PingEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified PingEvent message, length delimited. Does not implicitly {@link warbase.PingEvent.verify|verify} messages.
         * @param message PingEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.PingEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a PingEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.PingEvent & warbase.PingEvent.$Shape} PingEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.PingEvent & warbase.PingEvent.$Shape;

        /**
         * Decodes a PingEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.PingEvent & warbase.PingEvent.$Shape} PingEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.PingEvent & warbase.PingEvent.$Shape;

        /**
         * Verifies a PingEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a PingEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns PingEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.PingEvent;

        /**
         * Creates a plain object from a PingEvent message. Also converts values to other types if specified.
         * @param message PingEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.PingEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this PingEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for PingEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace PingEvent {

        /** Properties of a PingEvent. */
        interface $Properties {

            /** PingEvent clientTime */
            clientTime?: (number|Long|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a PingEvent. */
        type $Shape = warbase.PingEvent.$Properties;
    }

    /**
     * Properties of a ServerMessage.
     * @deprecated Use warbase.ServerMessage.$Properties instead.
     */
    interface IServerMessage extends warbase.ServerMessage.$Properties {
    }

    /** Represents a ServerMessage. */
    class ServerMessage {

        /**
         * Constructs a new ServerMessage.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.ServerMessage.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** ServerMessage gameState. */
        gameState?: (warbase.GameState.$Properties|null);

        /** ServerMessage serverEvent. */
        serverEvent?: (warbase.ServerEvent.$Properties|null);

        /** ServerMessage message. */
        message?: ("gameState"|"serverEvent");

        /**
         * Creates a new ServerMessage instance using the specified properties.
         * @param [properties] Properties to set
         * @returns ServerMessage instance
         */
        static create(properties: warbase.ServerMessage.$Shape): warbase.ServerMessage & warbase.ServerMessage.$Shape;
        static create(properties?: warbase.ServerMessage.$Properties): warbase.ServerMessage;

        /**
         * Encodes the specified ServerMessage message. Does not implicitly {@link warbase.ServerMessage.verify|verify} messages.
         * @param message ServerMessage message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.ServerMessage.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified ServerMessage message, length delimited. Does not implicitly {@link warbase.ServerMessage.verify|verify} messages.
         * @param message ServerMessage message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.ServerMessage.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a ServerMessage message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.ServerMessage & warbase.ServerMessage.$Shape} ServerMessage
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.ServerMessage & warbase.ServerMessage.$Shape;

        /**
         * Decodes a ServerMessage message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.ServerMessage & warbase.ServerMessage.$Shape} ServerMessage
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.ServerMessage & warbase.ServerMessage.$Shape;

        /**
         * Verifies a ServerMessage message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a ServerMessage message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns ServerMessage
         */
        static fromObject(object: { [k: string]: any }): warbase.ServerMessage;

        /**
         * Creates a plain object from a ServerMessage message. Also converts values to other types if specified.
         * @param message ServerMessage
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.ServerMessage, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this ServerMessage to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for ServerMessage
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace ServerMessage {

        /** Properties of a ServerMessage. */
        interface $Properties {

            /** ServerMessage gameState */
            gameState?: (warbase.GameState.$Properties|null);

            /** ServerMessage serverEvent */
            serverEvent?: (warbase.ServerEvent.$Properties|null);

            /** ServerMessage message */
            message?: ("gameState"|"serverEvent");

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Narrowed shape of a ServerMessage. */
        type $Shape = {
          gameState?: warbase.GameState.$Shape|null;
          serverEvent?: warbase.ServerEvent.$Shape|null;
          $unknowns?: Uint8Array[];
        } & (
          ({ message?: undefined; gameState?: null; serverEvent?: null }|{ message?: "gameState"; gameState: warbase.GameState.$Shape; serverEvent?: null }|{ message?: "serverEvent"; gameState?: null; serverEvent: warbase.ServerEvent.$Shape })
        );
    }

    /**
     * Properties of a GameState.
     * @deprecated Use warbase.GameState.$Properties instead.
     */
    interface IGameState extends warbase.GameState.$Properties {
    }

    /** Represents a GameState. */
    class GameState {

        /**
         * Constructs a new GameState.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.GameState.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** GameState players. */
        players: { [k: string]: warbase.PlayerState.$Properties };

        /** GameState roomMode. */
        roomMode: string;

        /** GameState roomState. */
        roomState: string;

        /** GameState scoreTeamA. */
        scoreTeamA: number;

        /** GameState scoreTeamB. */
        scoreTeamB: number;

        /** GameState winnerId. */
        winnerId: string;

        /**
         * Creates a new GameState instance using the specified properties.
         * @param [properties] Properties to set
         * @returns GameState instance
         */
        static create(properties: warbase.GameState.$Shape): warbase.GameState & warbase.GameState.$Shape;
        static create(properties?: warbase.GameState.$Properties): warbase.GameState;

        /**
         * Encodes the specified GameState message. Does not implicitly {@link warbase.GameState.verify|verify} messages.
         * @param message GameState message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.GameState.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified GameState message, length delimited. Does not implicitly {@link warbase.GameState.verify|verify} messages.
         * @param message GameState message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.GameState.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a GameState message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.GameState & warbase.GameState.$Shape} GameState
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.GameState & warbase.GameState.$Shape;

        /**
         * Decodes a GameState message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.GameState & warbase.GameState.$Shape} GameState
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.GameState & warbase.GameState.$Shape;

        /**
         * Verifies a GameState message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a GameState message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns GameState
         */
        static fromObject(object: { [k: string]: any }): warbase.GameState;

        /**
         * Creates a plain object from a GameState message. Also converts values to other types if specified.
         * @param message GameState
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.GameState, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this GameState to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for GameState
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace GameState {

        /** Properties of a GameState. */
        interface $Properties {

            /** GameState players */
            players?: ({ [k: string]: warbase.PlayerState.$Properties }|null);

            /** GameState roomMode */
            roomMode?: (string|null);

            /** GameState roomState */
            roomState?: (string|null);

            /** GameState scoreTeamA */
            scoreTeamA?: (number|null);

            /** GameState scoreTeamB */
            scoreTeamB?: (number|null);

            /** GameState winnerId */
            winnerId?: (string|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a GameState. */
        type $Shape = warbase.GameState.$Properties;
    }

    /**
     * Properties of a PlayerState.
     * @deprecated Use warbase.PlayerState.$Properties instead.
     */
    interface IPlayerState extends warbase.PlayerState.$Properties {
    }

    /** Represents a PlayerState. */
    class PlayerState {

        /**
         * Constructs a new PlayerState.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.PlayerState.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** PlayerState x. */
        x: number;

        /** PlayerState y. */
        y: number;

        /** PlayerState z. */
        z: number;

        /** PlayerState rx. */
        rx: number;

        /** PlayerState ry. */
        ry: number;

        /** PlayerState rz. */
        rz: number;

        /** PlayerState rw. */
        rw: number;

        /** PlayerState animation. */
        animation: string;

        /** PlayerState health. */
        health: number;

        /** PlayerState kills. */
        kills: number;

        /** PlayerState deaths. */
        deaths: number;

        /** PlayerState isDead. */
        isDead: boolean;

        /** PlayerState platformId. */
        platformId: string;

        /** PlayerState ping. */
        ping: number;

        /** PlayerState weaponId. */
        weaponId: string;

        /** PlayerState team. */
        team: string;

        /**
         * Creates a new PlayerState instance using the specified properties.
         * @param [properties] Properties to set
         * @returns PlayerState instance
         */
        static create(properties: warbase.PlayerState.$Shape): warbase.PlayerState & warbase.PlayerState.$Shape;
        static create(properties?: warbase.PlayerState.$Properties): warbase.PlayerState;

        /**
         * Encodes the specified PlayerState message. Does not implicitly {@link warbase.PlayerState.verify|verify} messages.
         * @param message PlayerState message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.PlayerState.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified PlayerState message, length delimited. Does not implicitly {@link warbase.PlayerState.verify|verify} messages.
         * @param message PlayerState message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.PlayerState.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a PlayerState message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.PlayerState & warbase.PlayerState.$Shape} PlayerState
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.PlayerState & warbase.PlayerState.$Shape;

        /**
         * Decodes a PlayerState message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.PlayerState & warbase.PlayerState.$Shape} PlayerState
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.PlayerState & warbase.PlayerState.$Shape;

        /**
         * Verifies a PlayerState message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a PlayerState message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns PlayerState
         */
        static fromObject(object: { [k: string]: any }): warbase.PlayerState;

        /**
         * Creates a plain object from a PlayerState message. Also converts values to other types if specified.
         * @param message PlayerState
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.PlayerState, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this PlayerState to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for PlayerState
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace PlayerState {

        /** Properties of a PlayerState. */
        interface $Properties {

            /** PlayerState x */
            x?: (number|null);

            /** PlayerState y */
            y?: (number|null);

            /** PlayerState z */
            z?: (number|null);

            /** PlayerState rx */
            rx?: (number|null);

            /** PlayerState ry */
            ry?: (number|null);

            /** PlayerState rz */
            rz?: (number|null);

            /** PlayerState rw */
            rw?: (number|null);

            /** PlayerState animation */
            animation?: (string|null);

            /** PlayerState health */
            health?: (number|null);

            /** PlayerState kills */
            kills?: (number|null);

            /** PlayerState deaths */
            deaths?: (number|null);

            /** PlayerState isDead */
            isDead?: (boolean|null);

            /** PlayerState platformId */
            platformId?: (string|null);

            /** PlayerState ping */
            ping?: (number|null);

            /** PlayerState weaponId */
            weaponId?: (string|null);

            /** PlayerState team */
            team?: (string|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a PlayerState. */
        type $Shape = warbase.PlayerState.$Properties;
    }

    /**
     * Properties of a ServerEvent.
     * @deprecated Use warbase.ServerEvent.$Properties instead.
     */
    interface IServerEvent extends warbase.ServerEvent.$Properties {
    }

    /** Represents a ServerEvent. */
    class ServerEvent {

        /**
         * Constructs a new ServerEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.ServerEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** ServerEvent respawn. */
        respawn?: (warbase.RespawnEvent.$Properties|null);

        /** ServerEvent fire. */
        fire?: (warbase.ServerFireEvent.$Properties|null);

        /** ServerEvent hitConfirmed. */
        hitConfirmed?: (warbase.HitConfirmedEvent.$Properties|null);

        /** ServerEvent killConfirmed. */
        killConfirmed?: (warbase.KillConfirmedEvent.$Properties|null);

        /** ServerEvent throwGrenade. */
        throwGrenade?: (warbase.ServerThrowGrenadeEvent.$Properties|null);

        /** ServerEvent pong. */
        pong?: (warbase.ServerPongEvent.$Properties|null);

        /** ServerEvent event. */
        event?: ("respawn"|"fire"|"hitConfirmed"|"killConfirmed"|"throwGrenade"|"pong");

        /**
         * Creates a new ServerEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns ServerEvent instance
         */
        static create(properties: warbase.ServerEvent.$Shape): warbase.ServerEvent & warbase.ServerEvent.$Shape;
        static create(properties?: warbase.ServerEvent.$Properties): warbase.ServerEvent;

        /**
         * Encodes the specified ServerEvent message. Does not implicitly {@link warbase.ServerEvent.verify|verify} messages.
         * @param message ServerEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.ServerEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified ServerEvent message, length delimited. Does not implicitly {@link warbase.ServerEvent.verify|verify} messages.
         * @param message ServerEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.ServerEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a ServerEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.ServerEvent & warbase.ServerEvent.$Shape} ServerEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.ServerEvent & warbase.ServerEvent.$Shape;

        /**
         * Decodes a ServerEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.ServerEvent & warbase.ServerEvent.$Shape} ServerEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.ServerEvent & warbase.ServerEvent.$Shape;

        /**
         * Verifies a ServerEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a ServerEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns ServerEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.ServerEvent;

        /**
         * Creates a plain object from a ServerEvent message. Also converts values to other types if specified.
         * @param message ServerEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.ServerEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this ServerEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for ServerEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace ServerEvent {

        /** Properties of a ServerEvent. */
        interface $Properties {

            /** ServerEvent respawn */
            respawn?: (warbase.RespawnEvent.$Properties|null);

            /** ServerEvent fire */
            fire?: (warbase.ServerFireEvent.$Properties|null);

            /** ServerEvent hitConfirmed */
            hitConfirmed?: (warbase.HitConfirmedEvent.$Properties|null);

            /** ServerEvent killConfirmed */
            killConfirmed?: (warbase.KillConfirmedEvent.$Properties|null);

            /** ServerEvent throwGrenade */
            throwGrenade?: (warbase.ServerThrowGrenadeEvent.$Properties|null);

            /** ServerEvent pong */
            pong?: (warbase.ServerPongEvent.$Properties|null);

            /** ServerEvent event */
            event?: ("respawn"|"fire"|"hitConfirmed"|"killConfirmed"|"throwGrenade"|"pong");

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Narrowed shape of a ServerEvent. */
        type $Shape = {
          respawn?: warbase.RespawnEvent.$Shape|null;
          fire?: warbase.ServerFireEvent.$Shape|null;
          hitConfirmed?: warbase.HitConfirmedEvent.$Shape|null;
          killConfirmed?: warbase.KillConfirmedEvent.$Shape|null;
          throwGrenade?: warbase.ServerThrowGrenadeEvent.$Shape|null;
          pong?: warbase.ServerPongEvent.$Shape|null;
          $unknowns?: Uint8Array[];
        } & (
          ({ event?: undefined; respawn?: null; fire?: null; hitConfirmed?: null; killConfirmed?: null; throwGrenade?: null; pong?: null }|{ event?: "respawn"; respawn: warbase.RespawnEvent.$Shape; fire?: null; hitConfirmed?: null; killConfirmed?: null; throwGrenade?: null; pong?: null }|{ event?: "fire"; respawn?: null; fire: warbase.ServerFireEvent.$Shape; hitConfirmed?: null; killConfirmed?: null; throwGrenade?: null; pong?: null }|{ event?: "hitConfirmed"; respawn?: null; fire?: null; hitConfirmed: warbase.HitConfirmedEvent.$Shape; killConfirmed?: null; throwGrenade?: null; pong?: null }|{ event?: "killConfirmed"; respawn?: null; fire?: null; hitConfirmed?: null; killConfirmed: warbase.KillConfirmedEvent.$Shape; throwGrenade?: null; pong?: null }|{ event?: "throwGrenade"; respawn?: null; fire?: null; hitConfirmed?: null; killConfirmed?: null; throwGrenade: warbase.ServerThrowGrenadeEvent.$Shape; pong?: null }|{ event?: "pong"; respawn?: null; fire?: null; hitConfirmed?: null; killConfirmed?: null; throwGrenade?: null; pong: warbase.ServerPongEvent.$Shape })
        );
    }

    /**
     * Properties of a RespawnEvent.
     * @deprecated Use warbase.RespawnEvent.$Properties instead.
     */
    interface IRespawnEvent extends warbase.RespawnEvent.$Properties {
    }

    /** Represents a RespawnEvent. */
    class RespawnEvent {

        /**
         * Constructs a new RespawnEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.RespawnEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** RespawnEvent x. */
        x: number;

        /** RespawnEvent y. */
        y: number;

        /** RespawnEvent z. */
        z: number;

        /**
         * Creates a new RespawnEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns RespawnEvent instance
         */
        static create(properties: warbase.RespawnEvent.$Shape): warbase.RespawnEvent & warbase.RespawnEvent.$Shape;
        static create(properties?: warbase.RespawnEvent.$Properties): warbase.RespawnEvent;

        /**
         * Encodes the specified RespawnEvent message. Does not implicitly {@link warbase.RespawnEvent.verify|verify} messages.
         * @param message RespawnEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.RespawnEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified RespawnEvent message, length delimited. Does not implicitly {@link warbase.RespawnEvent.verify|verify} messages.
         * @param message RespawnEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.RespawnEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a RespawnEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.RespawnEvent & warbase.RespawnEvent.$Shape} RespawnEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.RespawnEvent & warbase.RespawnEvent.$Shape;

        /**
         * Decodes a RespawnEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.RespawnEvent & warbase.RespawnEvent.$Shape} RespawnEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.RespawnEvent & warbase.RespawnEvent.$Shape;

        /**
         * Verifies a RespawnEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a RespawnEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns RespawnEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.RespawnEvent;

        /**
         * Creates a plain object from a RespawnEvent message. Also converts values to other types if specified.
         * @param message RespawnEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.RespawnEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this RespawnEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for RespawnEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace RespawnEvent {

        /** Properties of a RespawnEvent. */
        interface $Properties {

            /** RespawnEvent x */
            x?: (number|null);

            /** RespawnEvent y */
            y?: (number|null);

            /** RespawnEvent z */
            z?: (number|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a RespawnEvent. */
        type $Shape = warbase.RespawnEvent.$Properties;
    }

    /**
     * Properties of a ServerFireEvent.
     * @deprecated Use warbase.ServerFireEvent.$Properties instead.
     */
    interface IServerFireEvent extends warbase.ServerFireEvent.$Properties {
    }

    /** Represents a ServerFireEvent. */
    class ServerFireEvent {

        /**
         * Constructs a new ServerFireEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.ServerFireEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** ServerFireEvent shooterId. */
        shooterId: string;

        /** ServerFireEvent originX. */
        originX: number;

        /** ServerFireEvent originY. */
        originY: number;

        /** ServerFireEvent originZ. */
        originZ: number;

        /** ServerFireEvent hitX. */
        hitX: number;

        /** ServerFireEvent hitY. */
        hitY: number;

        /** ServerFireEvent hitZ. */
        hitZ: number;

        /** ServerFireEvent normalX. */
        normalX: number;

        /** ServerFireEvent normalY. */
        normalY: number;

        /** ServerFireEvent normalZ. */
        normalZ: number;

        /** ServerFireEvent hitWall. */
        hitWall: boolean;

        /**
         * Creates a new ServerFireEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns ServerFireEvent instance
         */
        static create(properties: warbase.ServerFireEvent.$Shape): warbase.ServerFireEvent & warbase.ServerFireEvent.$Shape;
        static create(properties?: warbase.ServerFireEvent.$Properties): warbase.ServerFireEvent;

        /**
         * Encodes the specified ServerFireEvent message. Does not implicitly {@link warbase.ServerFireEvent.verify|verify} messages.
         * @param message ServerFireEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.ServerFireEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified ServerFireEvent message, length delimited. Does not implicitly {@link warbase.ServerFireEvent.verify|verify} messages.
         * @param message ServerFireEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.ServerFireEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a ServerFireEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.ServerFireEvent & warbase.ServerFireEvent.$Shape} ServerFireEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.ServerFireEvent & warbase.ServerFireEvent.$Shape;

        /**
         * Decodes a ServerFireEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.ServerFireEvent & warbase.ServerFireEvent.$Shape} ServerFireEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.ServerFireEvent & warbase.ServerFireEvent.$Shape;

        /**
         * Verifies a ServerFireEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a ServerFireEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns ServerFireEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.ServerFireEvent;

        /**
         * Creates a plain object from a ServerFireEvent message. Also converts values to other types if specified.
         * @param message ServerFireEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.ServerFireEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this ServerFireEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for ServerFireEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace ServerFireEvent {

        /** Properties of a ServerFireEvent. */
        interface $Properties {

            /** ServerFireEvent shooterId */
            shooterId?: (string|null);

            /** ServerFireEvent originX */
            originX?: (number|null);

            /** ServerFireEvent originY */
            originY?: (number|null);

            /** ServerFireEvent originZ */
            originZ?: (number|null);

            /** ServerFireEvent hitX */
            hitX?: (number|null);

            /** ServerFireEvent hitY */
            hitY?: (number|null);

            /** ServerFireEvent hitZ */
            hitZ?: (number|null);

            /** ServerFireEvent normalX */
            normalX?: (number|null);

            /** ServerFireEvent normalY */
            normalY?: (number|null);

            /** ServerFireEvent normalZ */
            normalZ?: (number|null);

            /** ServerFireEvent hitWall */
            hitWall?: (boolean|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a ServerFireEvent. */
        type $Shape = warbase.ServerFireEvent.$Properties;
    }

    /**
     * Properties of a HitConfirmedEvent.
     * @deprecated Use warbase.HitConfirmedEvent.$Properties instead.
     */
    interface IHitConfirmedEvent extends warbase.HitConfirmedEvent.$Properties {
    }

    /** Represents a HitConfirmedEvent. */
    class HitConfirmedEvent {

        /**
         * Constructs a new HitConfirmedEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.HitConfirmedEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /**
         * Creates a new HitConfirmedEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns HitConfirmedEvent instance
         */
        static create(properties: warbase.HitConfirmedEvent.$Shape): warbase.HitConfirmedEvent & warbase.HitConfirmedEvent.$Shape;
        static create(properties?: warbase.HitConfirmedEvent.$Properties): warbase.HitConfirmedEvent;

        /**
         * Encodes the specified HitConfirmedEvent message. Does not implicitly {@link warbase.HitConfirmedEvent.verify|verify} messages.
         * @param message HitConfirmedEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.HitConfirmedEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified HitConfirmedEvent message, length delimited. Does not implicitly {@link warbase.HitConfirmedEvent.verify|verify} messages.
         * @param message HitConfirmedEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.HitConfirmedEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a HitConfirmedEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.HitConfirmedEvent & warbase.HitConfirmedEvent.$Shape} HitConfirmedEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.HitConfirmedEvent & warbase.HitConfirmedEvent.$Shape;

        /**
         * Decodes a HitConfirmedEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.HitConfirmedEvent & warbase.HitConfirmedEvent.$Shape} HitConfirmedEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.HitConfirmedEvent & warbase.HitConfirmedEvent.$Shape;

        /**
         * Verifies a HitConfirmedEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a HitConfirmedEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns HitConfirmedEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.HitConfirmedEvent;

        /**
         * Creates a plain object from a HitConfirmedEvent message. Also converts values to other types if specified.
         * @param message HitConfirmedEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.HitConfirmedEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this HitConfirmedEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for HitConfirmedEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace HitConfirmedEvent {

        /** Properties of a HitConfirmedEvent. */
        interface $Properties {

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a HitConfirmedEvent. */
        type $Shape = warbase.HitConfirmedEvent.$Properties;
    }

    /**
     * Properties of a KillConfirmedEvent.
     * @deprecated Use warbase.KillConfirmedEvent.$Properties instead.
     */
    interface IKillConfirmedEvent extends warbase.KillConfirmedEvent.$Properties {
    }

    /** Represents a KillConfirmedEvent. */
    class KillConfirmedEvent {

        /**
         * Constructs a new KillConfirmedEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.KillConfirmedEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /**
         * Creates a new KillConfirmedEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns KillConfirmedEvent instance
         */
        static create(properties: warbase.KillConfirmedEvent.$Shape): warbase.KillConfirmedEvent & warbase.KillConfirmedEvent.$Shape;
        static create(properties?: warbase.KillConfirmedEvent.$Properties): warbase.KillConfirmedEvent;

        /**
         * Encodes the specified KillConfirmedEvent message. Does not implicitly {@link warbase.KillConfirmedEvent.verify|verify} messages.
         * @param message KillConfirmedEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.KillConfirmedEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified KillConfirmedEvent message, length delimited. Does not implicitly {@link warbase.KillConfirmedEvent.verify|verify} messages.
         * @param message KillConfirmedEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.KillConfirmedEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a KillConfirmedEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.KillConfirmedEvent & warbase.KillConfirmedEvent.$Shape} KillConfirmedEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.KillConfirmedEvent & warbase.KillConfirmedEvent.$Shape;

        /**
         * Decodes a KillConfirmedEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.KillConfirmedEvent & warbase.KillConfirmedEvent.$Shape} KillConfirmedEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.KillConfirmedEvent & warbase.KillConfirmedEvent.$Shape;

        /**
         * Verifies a KillConfirmedEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a KillConfirmedEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns KillConfirmedEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.KillConfirmedEvent;

        /**
         * Creates a plain object from a KillConfirmedEvent message. Also converts values to other types if specified.
         * @param message KillConfirmedEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.KillConfirmedEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this KillConfirmedEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for KillConfirmedEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace KillConfirmedEvent {

        /** Properties of a KillConfirmedEvent. */
        interface $Properties {

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a KillConfirmedEvent. */
        type $Shape = warbase.KillConfirmedEvent.$Properties;
    }

    /**
     * Properties of a ServerThrowGrenadeEvent.
     * @deprecated Use warbase.ServerThrowGrenadeEvent.$Properties instead.
     */
    interface IServerThrowGrenadeEvent extends warbase.ServerThrowGrenadeEvent.$Properties {
    }

    /** Represents a ServerThrowGrenadeEvent. */
    class ServerThrowGrenadeEvent {

        /**
         * Constructs a new ServerThrowGrenadeEvent.
         * @param [properties] Properties to set
         */
        constructor(properties?: warbase.ServerThrowGrenadeEvent.$Properties);

        /** Unknown fields preserved while decoding when enabled */
        $unknowns?: Uint8Array[];

        /** ServerThrowGrenadeEvent shooterId. */
        shooterId: string;

        /** ServerThrowGrenadeEvent px. */
        px: number;

        /** ServerThrowGrenadeEvent py. */
        py: number;

        /** ServerThrowGrenadeEvent pz. */
        pz: number;

        /** ServerThrowGrenadeEvent vx. */
        vx: number;

        /** ServerThrowGrenadeEvent vy. */
        vy: number;

        /** ServerThrowGrenadeEvent vz. */
        vz: number;

        /**
         * Creates a new ServerThrowGrenadeEvent instance using the specified properties.
         * @param [properties] Properties to set
         * @returns ServerThrowGrenadeEvent instance
         */
        static create(properties: warbase.ServerThrowGrenadeEvent.$Shape): warbase.ServerThrowGrenadeEvent & warbase.ServerThrowGrenadeEvent.$Shape;
        static create(properties?: warbase.ServerThrowGrenadeEvent.$Properties): warbase.ServerThrowGrenadeEvent;

        /**
         * Encodes the specified ServerThrowGrenadeEvent message. Does not implicitly {@link warbase.ServerThrowGrenadeEvent.verify|verify} messages.
         * @param message ServerThrowGrenadeEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encode(message: warbase.ServerThrowGrenadeEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified ServerThrowGrenadeEvent message, length delimited. Does not implicitly {@link warbase.ServerThrowGrenadeEvent.verify|verify} messages.
         * @param message ServerThrowGrenadeEvent message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        static encodeDelimited(message: warbase.ServerThrowGrenadeEvent.$Properties, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a ServerThrowGrenadeEvent message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns {warbase.ServerThrowGrenadeEvent & warbase.ServerThrowGrenadeEvent.$Shape} ServerThrowGrenadeEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): warbase.ServerThrowGrenadeEvent & warbase.ServerThrowGrenadeEvent.$Shape;

        /**
         * Decodes a ServerThrowGrenadeEvent message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns {warbase.ServerThrowGrenadeEvent & warbase.ServerThrowGrenadeEvent.$Shape} ServerThrowGrenadeEvent
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): warbase.ServerThrowGrenadeEvent & warbase.ServerThrowGrenadeEvent.$Shape;

        /**
         * Verifies a ServerThrowGrenadeEvent message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a ServerThrowGrenadeEvent message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns ServerThrowGrenadeEvent
         */
        static fromObject(object: { [k: string]: any }): warbase.ServerThrowGrenadeEvent;

        /**
         * Creates a plain object from a ServerThrowGrenadeEvent message. Also converts values to other types if specified.
         * @param message ServerThrowGrenadeEvent
         * @param [options] Conversion options
         * @returns Plain object
         */
        static toObject(message: warbase.ServerThrowGrenadeEvent, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this ServerThrowGrenadeEvent to JSON.
         * @returns JSON object
         */
        toJSON(): { [k: string]: any };

        /**
         * Gets the type url for ServerThrowGrenadeEvent
         * @param [prefix] Custom type url prefix, defaults to `"type.googleapis.com"`
         * @returns The type url
         */
        static getTypeUrl(prefix?: string): string;
    }

    namespace ServerThrowGrenadeEvent {

        /** Properties of a ServerThrowGrenadeEvent. */
        interface $Properties {

            /** ServerThrowGrenadeEvent shooterId */
            shooterId?: (string|null);

            /** ServerThrowGrenadeEvent px */
            px?: (number|null);

            /** ServerThrowGrenadeEvent py */
            py?: (number|null);

            /** ServerThrowGrenadeEvent pz */
            pz?: (number|null);

            /** ServerThrowGrenadeEvent vx */
            vx?: (number|null);

            /** ServerThrowGrenadeEvent vy */
            vy?: (number|null);

            /** ServerThrowGrenadeEvent vz */
            vz?: (number|null);

            /** Unknown fields preserved while decoding when enabled */
            $unknowns?: Uint8Array[];
        }

        /** Shape of a ServerThrowGrenadeEvent. */
        type $Shape = warbase.ServerThrowGrenadeEvent.$Properties;
    }
}
