module dtg.app;

import std;
import dtg.database, dtg.entrycache, dtg.mkdocs;

void main(string[] args)
{
    string dataFolder = buildPath(getcwd, "data");
    string outputFolder = buildPath(getcwd, "output");

    auto database = new Database(dataFolder);
    auto entryCache = new EntryCache();
    entryCache.addEntries(database.entries);

    if (args.length == 1 || (args.length == 2 && args[1] == "build"))
    {
        new MkdocsBuilder(outputFolder, database, entryCache).build();
    }

    if (args.length == 2 && args[1] == "validate")
    {
        writeln("Validated");
    }
}
