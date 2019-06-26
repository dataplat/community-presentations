import-module dbatools,BurntToast -Verbose:$false;

$PSDefaultParameterValues['*:SqlInstance'] = 'ctx1315\sql16';
$PSDefaultParameterValues['Import-DbaCsv:Database'] = 'Movies';
$PSDefaultParameterValues['Import-DbaCsv:Schema'] = 'dbo';
$PSDefaultParameterValues['Import-DbaCsv:Delimiter'] = [System.Convert]::ToChar(9);
$PSDefaultParameterValues['Import-DbaCsv:SkipEmptyLine'] = $true;
$PSDefaultParameterValues['Import-DbaCsv:ParseErrorAction'] = 'AdvanceToNextLine';
$PSDefaultParameterValues['Import-DbaCsv:UseColumnDefault'] = $false;
$PSDefaultParameterValues['Import-DbaCsv:KeepNulls'] = $true;
$PSDefaultParameterValues['Import-DbaCsv:Truncate'] = $true;
$PSDefaultParameterValues['Import-DbaCsv:AutoCreateTable'] = $true;

# Drop and recreate the database
Remove-DbaDatabase -Database Movies;
New-DbaDatabase -Name Movies -PrimaryFilesize 1024 -PrimaryFileGrowth 1024 -LogSize 16 -LogGrowth 16;

# AKAs
$ColumnMap = @{
    titleId         = 'TitleId'
    ordering        = 'Ordering'
    title           = 'LocalizedTitle'
    region          = 'Region'
    language        = 'Language'
    types           = 'UsageList'
    attributes      = 'AttributeList'
    isOriginalTitle = 'IsOriginalTitle'
};
Import-DbaCsv -table Aka -Path 'C:\Users\andy.levy\OneDrive - Volaris Group\dbatools talk\MovieData\title.akas.tsv';

# Title Basics
$ColumnMap = @{
    tconst         = 'TitleId'
    titleType      = 'TitleFormat'
    primaryTitle   = 'CommonTitle'
    originalTitle  = 'OrigTitle'
    isAdult        = 'IsAdult'
    startYear      = 'ReleaseYear'
    endYear        = 'EndYear'
    runtimeMinutes = 'Runtime'
    genres         = 'GenreList'
};
Import-DbaCsv -table TitleBasics -Path 'C:\Users\andy.levy\OneDrive - Volaris Group\dbatools talk\MovieData\title.basics.tsv';

# Crew
$ColumnMap = @{
    tconst    = 'TitleId'
    directors = 'DirectorList'
    writers   = 'WriterList'
};
Import-DbaCsv -table Crew -Path 'C:\Users\andy.levy\OneDrive - Volaris Group\dbatools talk\MovieData\title.crew.tsv';

#Episodes
$ColumnMap = @{
    tconst        = 'EpisodeId'
    parentTConst  = 'SeriesId'
    seasonNumber  = 'Season'
    episodeNumber = 'Episode'
};
Import-DbaCsv -table Episode -Path 'C:\Users\andy.levy\OneDrive - Volaris Group\dbatools talk\MovieData\title.episode.tsv';

# Principal
$ColumnMap = @{
    tconst     = 'TitleId'
    ordering   = 'SortOrder'
    nconst     = 'NameId'
    category   = 'JobCategory'
    job        = 'JobName'
    characters = 'Role'
};
Import-DbaCsv -table Principal -Path 'C:\Users\andy.levy\OneDrive - Volaris Group\dbatools talk\MovieData\title.principals.tsv';

# Ratings
$ColumnMap = @{
    tconst        = 'TitleId'
    averageRating = 'AvgRating'
    numVotes      = 'NumVotes'
};
Import-DbaCsv -table Ratings -Path 'C:\Users\andy.levy\OneDrive - Volaris Group\dbatools talk\MovieData\title.ratings.tsv';

# Names
$ColumnMap = @{
    nconst            = 'PersonId'
    primaryName       = 'CommonName'
    birthYear         = 'Born'
    deathYear         = 'Died'
    primaryProfession = 'ProfessionList'
    knownForTitles    = 'KnownForList'
};
Import-DbaCsv -table NameBasics -Path 'C:\Users\andy.levy\OneDrive - Volaris Group\dbatools talk\MovieData\name.basics.tsv';

New-BurntToastNotification -Text "IMDB Import Complete"