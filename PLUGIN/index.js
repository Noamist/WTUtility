
(vendetta) => {
    const state = {
        dispatcher: null,
        callback: null,
        userId: null,
        pending: new Map(),
        rows: [],
        active: false
    };

    const log = (...args) =>
        console.log("[DiscordTimestampLogger]", ...args);

    function timestampOf(message) {
        const value = message?.timestamp;
        const result = value instanceof Date
            ? value.getTime()
            : typeof value === "number"
                ? (value < 1e12 ? value * 1000 : value)
                : Date.parse(value);

        return Number.isFinite(result) ? result : Date.now();
    }

    function handleMessage(action) {
        const message = action?.message;
        if (!message) return;

        const channelId =
            message.channel_id || message.channelId || action.channelId;
        const authorId =
            message.author?.id || message.author_id || message.authorId;

        if (!channelId || !authorId) return;

        const time = timestampOf(message);

        if (authorId === state.userId) {
            if (!state.pending.has(channelId)) {
                state.pending.set(channelId, []);
            }

            state.pending.get(channelId).push({
                channelId,
                messageId: message.id || "",
                sentMs: time
            });

            log("Message envoyé détecté", channelId, time);
            return;
        }

        if (message.author?.bot !== true) return;

        const queue = state.pending.get(channelId);
        if (!queue?.length) return;

        const reference =
            message.message_reference?.message_id ||
            message.messageReference?.message_id;

        let index = 0;
        if (reference) {
            const found = queue.findIndex(
                item => item.messageId === reference
            );
            if (found !== -1) index = found;
        }

        const sent = queue.splice(index, 1)[0];
        if (!queue.length) state.pending.delete(channelId);

        const replyMs = time;
        const row = {
            channelId,
            messageId: sent.messageId,
            replyMessageId: message.id || "",
            botId: authorId,
            sentISO: new Date(sent.sentMs).toISOString(),
            sentMs: sent.sentMs,
            replyISO: new Date(replyMs).toISOString(),
            replyMs,
            delayMs: replyMs - sent.sentMs
        };

        state.rows.push(row);
        log("Paire enregistrée", row);
    }

    function makeTXT() {
        const header = [
            "channel_id",
            "message_id",
            "reply_message_id",
            "bot_id",
            "envoi_iso",
            "envoi_unix_ms",
            "reponse_iso",
            "reponse_unix_ms",
            "delai_ms"
        ].join("\t");

        const lines = state.rows.map(row => [
            row.channelId,
            row.messageId,
            row.replyMessageId,
            row.botId,
            row.sentISO,
            row.sentMs,
            row.replyISO,
            row.replyMs,
            row.delayMs
        ].join("\t"));

        return [header, ...lines].join("\n") + "\n";
    }

    async function exportTXT() {
        try {
            const common = vendetta.metro?.common;
            const RN = common?.ReactNative;
            const Share = RN?.Share;

            if (!Share?.share) {
                throw new Error("Le menu de partage iOS est indisponible.");
            }

            await Share.share({
                title: "DiscordTimestampLogger.txt",
                message: makeTXT()
            });

            log("Export demandé", state.rows.length, "paires");
        } catch (error) {
            log("Erreur d'export", error);
        }
    }

    function start() {
        try {
            const metro = vendetta.metro;
            const findByProps = metro?.findByProps;
            const findByStoreName = metro?.findByStoreName;

            if (!findByProps) {
                throw new Error("API Metro indisponible.");
            }

            const userStore = findByStoreName?.("UserStore")
                || findByProps("getCurrentUser");

            const currentUser = userStore?.getCurrentUser?.();
            if (!currentUser?.id) {
                throw new Error("Utilisateur courant introuvable.");
            }

            const dispatcher = findByProps("_currentDispatchActionType");
            if (
                !dispatcher ||
                typeof dispatcher.subscribe !== "function" ||
                typeof dispatcher.unsubscribe !== "function"
            ) {
                throw new Error("Dispatcher Discord introuvable.");
            }

            state.userId = currentUser.id;
            state.dispatcher = dispatcher;
            state.callback = action => {
                try {
                    handleMessage(action);
                } catch (error) {
                    log("Erreur de traitement", error);
                }
            };

            dispatcher.subscribe("MESSAGE_CREATE", state.callback);
            state.active = true;

            // Fonction d'export accessible depuis la console de débogage.
            window.DiscordTimestampLoggerExport = exportTXT;
            window.DiscordTimestampLoggerGetData = makeTXT;

            log("Plugin activé. Paires enregistrées :", state.rows.length);
        } catch (error) {
            log("Impossible de démarrer le plugin", error);
            stop();
        }
    }

    function stop() {
        if (state.dispatcher && state.callback) {
            try {
                state.dispatcher.unsubscribe(
                    "MESSAGE_CREATE",
                    state.callback
                );
            } catch (error) {
                log("Erreur de désabonnement", error);
            }
        }

        delete window.DiscordTimestampLoggerExport;
        delete window.DiscordTimestampLoggerGetData;

        state.dispatcher = null;
        state.callback = null;
        state.active = false;
    }

    return {
        onLoad: start,
        onUnload: stop
    };
}
