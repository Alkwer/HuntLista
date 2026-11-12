/**
 * Hunt Lista Discord Bot
 * 
 * Komendy:
 *   /hunt add <nick> [powód]
 *   /hunt remove <nick>
 *   /hunt list
 *   /hunt info <nick>
 * 
 * Po każdej zmianie bot aktualizuje plik Data.lua na GitHubie.
 */

require('dotenv').config();
const { Client, GatewayIntentBits, REST, Routes, SlashCommandBuilder, EmbedBuilder } = require('discord.js');
const { Octokit } = require('octokit');
const { createDataStore, validateNick } = require('./data');

// ========== KONFIGURACJA ==========
const DISCORD_TOKEN = process.env.DISCORD_TOKEN;
const CLIENT_ID = process.env.CLIENT_ID;
const GUILD_ID = process.env.GUILD_ID;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_OWNER = process.env.GITHUB_OWNER || 'frethborn';
const GITHUB_REPO = process.env.GITHUB_REPO || 'HuntLista';
const GITHUB_PATH = process.env.GITHUB_PATH || 'HuntLista/Data.lua';

const store = createDataStore(new Octokit({ auth: GITHUB_TOKEN }), {
    owner: GITHUB_OWNER, repo: GITHUB_REPO, path: GITHUB_PATH,
});

const client = new Client({ intents: [GatewayIntentBits.Guilds] });

const commands = [
    new SlashCommandBuilder()
        .setName('hunt')
        .setDescription('Zarządzanie Hunt Listą')
        .addSubcommand(sub => sub.setName('add').setDescription('Dodaj gracza na listę')
            .addStringOption(o => o.setName('nick').setDescription('Nick gracza').setRequired(true).setMaxLength(64))
            .addStringOption(o => o.setName('powod').setDescription('Powód / notatka').setRequired(false).setMaxLength(1024)))
        .addSubcommand(sub => sub.setName('remove').setDescription('Usuń gracza z listy')
            .addStringOption(o => o.setName('nick').setDescription('Nick gracza').setRequired(true).setMaxLength(64)))
        .addSubcommand(sub => sub.setName('list').setDescription('Pokaż całą listę'))
        .addSubcommand(sub => sub.setName('info').setDescription('Szczegóły gracza')
            .addStringOption(o => o.setName('nick').setDescription('Nick gracza').setRequired(true).setMaxLength(64)))
].map(c => c.toJSON());

async function registerCommands() {
    const rest = new REST({ version: '10' }).setToken(DISCORD_TOKEN);
    try {
        if (GUILD_ID) {
            await rest.put(Routes.applicationGuildCommands(CLIENT_ID, GUILD_ID), { body: commands });
            console.log('Komendy zarejestrowane (guild).');
        } else {
            await rest.put(Routes.applicationCommands(CLIENT_ID), { body: commands });
            console.log('Komendy zarejestrowane (global).');
        }
    } catch (e) { console.error('Błąd rejestracji komend:', e); }
}

client.once('ready', () => {
    console.log(`Zalogowano jako ${client.user.tag}`);
});

function findPlayer(data, nick) {
    return Object.keys(data.players).find(key => key.toLowerCase() === nick.toLowerCase());
}

client.on('interactionCreate', async interaction => {
    if (!interaction.isChatInputCommand()) return;
    if (interaction.commandName !== 'hunt') return;

    const sub = interaction.options.getSubcommand();
    const user = interaction.user.username;
    try {
        const nick = sub === 'list' ? null : validateNick(interaction.options.getString('nick'));
        const reason = sub === 'add' ? interaction.options.getString('powod') || '' : '';
        if (reason.length > 1024) throw new Error('Powód może mieć najwyżej 1024 znaki.');
        await interaction.deferReply();

        if (sub === 'add') {
            const { data } = await store.update(data => {
                const key = findPlayer(data, nick) || nick;
                data.players[key] = { reason, addedBy: user, addedAt: new Date().toISOString().slice(0, 10), note: '' };
            });
            const embed = new EmbedBuilder().setColor(0xff4444).setTitle('Dodano na Hunt Listę')
                .addFields(
                    { name: 'Nick', value: nick, inline: true },
                    { name: 'Dodał', value: user, inline: true },
                    { name: 'Powód', value: reason || '—', inline: false },
                    { name: 'Wersja danych', value: data.version, inline: true },
                ).setFooter({ text: 'Wypchnięto na GitHub – zaktualizujcie addon w grze' });
            await interaction.editReply({ embeds: [embed] });
        }
        else if (sub === 'remove') {
            let found;
            const { changed, data } = await store.update(data => {
                found = findPlayer(data, nick);
                if (!found) return false;
                delete data.players[found];
            });
            await interaction.editReply({ content: changed
                ? `Usunięto **${found}** z listy. Wersja: \`${data.version}\` (GitHub OK)`
                : `Nie ma **${nick}** na liście.` });
        }
        else if (sub === 'list') {
            const data = await store.read();
            const names = Object.keys(data.players).sort((a, b) => a.localeCompare(b));
            if (names.length === 0) { await interaction.editReply({ content: 'Lista jest pusta.' }); return; }
            let text = names.map(n => {
                const p = data.players[n];
                return `• **${n}**${p.reason ? ` — ${p.reason}` : ''} _(dodał: ${p.addedBy || '—'})_`;
            }).join('\n');
            if (text.length > 3900) text = text.slice(0, 3900) + '\n…';
            const embed = new EmbedBuilder().setColor(0xff4444).setTitle(`Hunt Lista (${names.length})`)
                .setDescription(text).setFooter({ text: `Wersja: ${data.version} • ${data.lastUpdate}` });
            await interaction.editReply({ embeds: [embed] });
        }
        else if (sub === 'info') {
            const data = await store.read();
            const found = findPlayer(data, nick);
            if (!found) { await interaction.editReply({ content: `Nie ma **${nick}** na liście.` }); return; }
            const p = data.players[found];
            const embed = new EmbedBuilder().setColor(0xff4444).setTitle(found.slice(0, 256))
                .addFields(
                    { name: 'Powód', value: (p.reason || '—').slice(0, 1024), inline: false },
                    { name: 'Dodał', value: (p.addedBy || '—').slice(0, 1024), inline: true },
                    { name: 'Data', value: (p.addedAt || '—').slice(0, 1024), inline: true },
                    { name: 'Notatka', value: (p.note || '—').slice(0, 1024), inline: false },
                );
            await interaction.editReply({ embeds: [embed] });
        }
    } catch (error) {
        console.error('Błąd komendy hunt:', error.message);
        const content = interaction.deferred
            ? 'Nie udało się potwierdzić operacji na GitHubie. Sprawdź /hunt list przed ponowieniem; przy konflikcie wersji ponów komendę.'
            : error.message;
        if (interaction.deferred) await interaction.editReply({ content });
        else await interaction.reply({ content, ephemeral: true });
    }
});

if (!DISCORD_TOKEN || !GITHUB_TOKEN) {
    console.error('Brak DISCORD_TOKEN lub GITHUB_TOKEN w .env');
    process.exit(1);
}

registerCommands().then(() => {
    client.login(DISCORD_TOKEN);
});
