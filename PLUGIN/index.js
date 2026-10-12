
/**
 * @name DiscordTimestampLogger
 * @author OpenAI
 * @version 1.0.0
 * @description Enregistre les timestamps des messages envoyés et des réponses des bots dans un fichier TXT.
 */

module.exports = class DiscordTimestampLogger {
    constructor() {
        this.pluginName = "DiscordTimestampLogger";
        this.dispatcher = null;
        this.callback = null;
        this.myUserId = null;
        this.pending = new Map();
        this.rows = [];
        this.started = false;
    }

    showToast(message, type = "info") {
        try {
            BdApi.UI.showToast(message, {
                type,
                timeout: type === "error" ? 5000 : 2500
            });
        } catch (error) {
            console.log("[DiscordTimestampLogger]", message);
        }
    }

    start() {
        try {
            const W = BdApi.Webpack;
            const messageStore = W.getStore("MessageStore");

            this.dispatcher = messageStore?._dispatcher;

            if (
                !this.dispatcher ||
                typeof this.dispatcher.subscribe !== "function" ||
                typeof this.dispatcher.unsubscribe !== "function"
            ) {
                throw new Error(
                    "Dispatcher introuvable dans MessageStore."
                );
            }

            const userStore = W.getStore("UserStore");
            const currentUser = userStore?.getCurrentUser?.();

            if (!currentUser?.id) {
                throw new Error(
                    "Impossible de récupérer ton identifiant Discord."
                );
            }

            this.myUserId = currentUser.id;

            this.callback = action => {
                try {
                    this.handleMessage(action);
                } catch (error) {
                    console.error(
                        "[DiscordTimestampLogger] Erreur de traitement :",
                        error
                    );
                }
            };

            this.dispatcher.subscribe("MESSAGE_CREATE", this.callback);
            this.started = true;

            // Fonction d'export accessible dans la console Discord.
            window.DiscordTimestampLoggerExport = () => this.exportTXT();

            this.showToast("Logger de timestamps activé", "success");

            console.log(
                "[DiscordTimestampLogger] Actif.",
                "Compte :", this.myUserId,
                "| Pour exporter : DiscordTimestampLoggerExport()"
            );
        } catch (error) {
            console.error(
                "[DiscordTimestampLogger] Erreur de démarrage :",
                error
            );

            this.showToast(
                "Échec du démarrage : " + error.message,
                "error"
            );

            this.stop();
        }
    }

    getTimestamp(message) {
        const timestamp = message?.timestamp;

        if (
            timestamp instanceof Date &&
            Number.isFinite(timestamp.getTime())
        ) {
            return timestamp.getTime();
        }

        if (
            typeof timestamp === "number" &&
            Number.isFinite(timestamp)
        ) {
            return timestamp < 100000000000
                ? Math.round(timestamp * 1000)
                : Math.round(timestamp);
        }

        if (typeof timestamp === "string") {
            const parsed = Date.parse(timestamp);

            if (Number.isFinite(parsed)) {
                return parsed;
            }
        }

        return Date.now();
    }

    handleMessage(action) {
        const message = action?.message;

        if (!message) return;

        const channelId =
            message.channel_id ||
            message.channelId ||
            action?.channelId;

        const authorId =
            message.author?.id ||
            message.author_id ||
            message.authorId;

        if (!channelId || !authorId) return;

        const timestampMs = this.getTimestamp(message);

        // Enregistrement d'un message envoyé par ton compte.
        if (authorId === this.myUserId) {
            if (!this.pending.has(channelId)) {
                this.pending.set(channelId, []);
            }

            this.pending.get(channelId).push({
                channelId,
                messageId: message.id || "",
                sentMs: timestampMs
            });

            console.log(
                "[DiscordTimestampLogger] Message envoyé détecté :",
                new Date(timestampMs).toISOString()
            );

            return;
        }

        // Ne conserve que les réponses provenant de comptes bots.
        if (message.author?.bot !== true) return;

        const queue = this.pending.get(channelId);

        if (!queue || queue.length === 0) return;

        // Recherche du message auquel le bot répond, si disponible.
        const referencedId =
            message.message_reference?.message_id ||
            message.messageReference?.message_id;

        let index = 0;

        if (referencedId) {
            const match = queue.findIndex(
                entry => entry.messageId === referencedId
            );

            if (match !== -1) {
                index = match;
            }
        }

        const sent = queue.splice(index, 1)[0];

        if (queue.length === 0) {
            this.pending.delete(channelId);
        }

        this.recordPair(
            sent,
            message,
            authorId,
            timestampMs
        );
    }

    recordPair(sent, reply, botId, replyMs) {
        const delayMs = replyMs - sent.sentMs;

        const row = {
            channelId: sent.channelId,
            messageId: sent.messageId,
            replyMessageId: reply.id || "",
            botId,
            sentISO: new Date(sent.sentMs).toISOString(),
            sentMs: sent.sentMs,
            replyISO: new Date(replyMs).toISOString(),
            replyMs,
            delayMs
        };

        this.rows.push(row);

        console.log(
            "[DiscordTimestampLogger] Paire enregistrée :",
            row
        );

        this.showToast(
            `Réponse enregistrée : ${delayMs} ms`,
            "success"
        );
    }

    exportTXT() {
        try {
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

            const lines = this.rows.map(row => [
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

            const content = [header, ...lines].join("\r\n") + "\r\n";

            const blob = new Blob(
                ["\uFEFF", content],
                { type: "text/plain;charset=utf-8" }
            );

            const url = URL.createObjectURL(blob);
            const link = document.createElement("a");

            link.href = url;
            link.download = "DiscordTimestampLogger.txt";

            document.body.appendChild(link);
            link.click();
            link.remove();

            setTimeout(() => URL.revokeObjectURL(url), 1500);

            this.showToast(
                `Export effectué : ${this.rows.length} paire(s)`,
                "success"
            );
        } catch (error) {
            console.error(
                "[DiscordTimestampLogger] Erreur d'export :",
                error
            );

            this.showToast(
                "Échec de l'export : " + error.message,
                "error"
            );
        }
    }

    stop() {
        if (this.dispatcher && this.callback) {
            try {
                this.dispatcher.unsubscribe(
                    "MESSAGE_CREATE",
                    this.callback
                );
            } catch (error) {
                console.error(
                    "[DiscordTimestampLogger] Désabonnement impossible :",
                    error
                );
            }
        }

        if (window.DiscordTimestampLoggerExport) {
            delete window.DiscordTimestampLoggerExport;
        }

        this.dispatcher = null;
        this.callback = null;
        this.started = false;

        this.pending.clear();

        console.log("[DiscordTimestampLogger] Arrêté.");
    }
};
