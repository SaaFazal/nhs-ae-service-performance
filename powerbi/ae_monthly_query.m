// Power Query (M): loads EVERY csv in data\raw, so a new month = drop the file in and press Refresh.
// It does the same cleaning as src/01_load_clean.py.
let
    FolderPath = "C:\Users\sahad\OneDrive\StartUP\portfolio-projects\nhs-ae-service-performance\data\raw",
    Source = Folder.Files(FolderPath),
    CsvFiles = Table.SelectRows(Source, each Text.Lower([Extension]) = ".csv" and Text.StartsWith([Name], "ae_")),
    Parsed = Table.AddColumn(CsvFiles, "Data", each Table.PromoteHeaders(
                 Csv.Document([Content], [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
                 [PromoteAllScalars = true])),
    Combined = Table.Combine(Parsed[Data]),

    // Drop the national total row at the bottom of every file
    ProvidersOnly = Table.SelectRows(Combined, each
                 Text.Upper(Text.Trim([Org Code])) <> "TOTAL"
                 and Text.StartsWith(Text.Upper(Text.Trim([Period])), "MSITAE-")),

    NumberCols = List.Skip(Table.ColumnNames(ProvidersOnly), 4),
    Typed = Table.TransformColumnTypes(ProvidersOnly, List.Transform(NumberCols, each {_, Int64.Type})),

    AttCols = List.Select(NumberCols, each Text.StartsWith(_, "A&E attendances")),
    Over4Cols = List.Select(NumberCols, each Text.StartsWith(_, "Attendances over 4hrs")),

    // "MSitAE-OCTOBER-2025" -> 1 Oct 2025
    AddMonth = Table.AddColumn(Typed, "Month", each Date.FromText(
                 "1 " & Text.Replace(Text.Proper(Text.AfterDelimiter(Text.Trim([Period]), "-")), "-", " "),
                 [Culture = "en-GB"]), type date),
    AddRegion = Table.AddColumn(AddMonth, "Region", each
                 Text.Proper(Text.Trim(Text.Replace(Text.Upper([Parent Org]), "NHS ENGLAND", ""))), type text),
    AddAtt = Table.AddColumn(AddRegion, "Attendances", each
                 List.Sum(Record.FieldValues(Record.SelectFields(_, AttCols))), Int64.Type),
    AddOver4 = Table.AddColumn(AddAtt, "Over 4hrs", each
                 List.Sum(Record.FieldValues(Record.SelectFields(_, Over4Cols))), Int64.Type),
    AddWithin4 = Table.AddColumn(AddOver4, "Within 4hrs", each [Attendances] - [Over 4hrs], Int64.Type),
    AddType1 = Table.AddColumn(AddWithin4, "Has Type 1 AE", each
                 if [#"A&E attendances Type 1"] > 0 then "Yes" else "No", type text),

    Renamed = Table.RenameColumns(AddType1, {
                 {"Org name", "Trust"},
                 {"Patients who have waited 12+ hrs from DTA to admission", "DTA 12hr Waits"}}),
    TrimTrust = Table.TransformColumns(Renamed, {{"Trust", Text.Trim, type text}}),
    Result = Table.SelectColumns(TrimTrust, {"Month", "Org Code", "Trust", "Region",
                 "Attendances", "Within 4hrs", "Over 4hrs", "DTA 12hr Waits", "Has Type 1 AE"})
in
    Result
