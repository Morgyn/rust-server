import { extract } from '@extractus/feed-extractor';

extract('https://github.com/OxideMod/Oxide.Rust/releases.atom').then( (data) => {

        const latestEntry = data.entries.reduce((latest, current) => {
          const latestDate = new Date(latest.published);
          const currentDate = new Date(current.published);
          return currentDate > latestDate ? current : latest;
        }, data.entries[0]);

        console.log(`https://github.com/OxideMod/Oxide.Rust/releases/download/${latestEntry.title}/Oxide.Rust-linux.zip`);
});