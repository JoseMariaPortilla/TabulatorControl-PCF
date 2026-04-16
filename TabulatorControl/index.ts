import { IInputs, IOutputs } from "./generated/ManifestTypes";
import { TabulatorFull } from "tabulator-tables";
import type { Options, ColumnDefinition, RowComponent } from "tabulator-tables";

export class TabulatorControl
  implements ComponentFramework.StandardControl<IInputs, IOutputs>
{
  // ── Referencias DOM ────────────────────────────────────────────────────────
  private _container: HTMLDivElement;
  private _tableDiv: HTMLDivElement;
  private _tabulator: TabulatorFull | null = null;

  // ── Estado interno ─────────────────────────────────────────────────────────
  private _selectedRow: string = "";
  private _notifyOutputChanged: () => void;

  // ── Cache para evitar re-renders innecesarios ──────────────────────────────
  private _lastDataJson: string = "";
  private _lastConfigJson: string = "";

  // ══════════════════════════════════════════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════════════════════════════════════════
  public init(
    context: ComponentFramework.Context<IInputs>,
    notifyOutputChanged: () => void,
    _state: ComponentFramework.Dictionary,
    container: HTMLDivElement
  ): void {
    this._notifyOutputChanged = notifyOutputChanged;
    this._container = container;
    this._container.classList.add("tabulator-pcf-root");

    // Div target para Tabulator
    this._tableDiv = document.createElement("div");
    this._tableDiv.id = `tabulator-${Date.now()}`;
    this._tableDiv.classList.add("tabulator-pcf-table");
    this._container.appendChild(this._tableDiv);

    this._renderTable(context);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE VIEW
  // ══════════════════════════════════════════════════════════════════════════
  public updateView(context: ComponentFramework.Context<IInputs>): void {
    const newData   = context.parameters.dataJson.raw   ?? "";
    const newConfig = context.parameters.configJson.raw ?? "";

    if (newData !== this._lastDataJson || newConfig !== this._lastConfigJson) {
      this._renderTable(context);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  getOutputs
  // ══════════════════════════════════════════════════════════════════════════
  public getOutputs(): IOutputs {
    return { selectedRow: this._selectedRow };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DESTROY
  // ══════════════════════════════════════════════════════════════════════════
  public destroy(): void {
    if (this._tabulator) {
      this._tabulator.destroy();
      this._tabulator = null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RENDER TABLE
  // ══════════════════════════════════════════════════════════════════════════
  private _renderTable(context: ComponentFramework.Context<IInputs>): void {
    const dataJson   = context.parameters.dataJson.raw   ?? "[]";
    const configJson = context.parameters.configJson.raw ?? "{}";

    this._lastDataJson   = dataJson;
    this._lastConfigJson = configJson;

    let tableData: object[]       = [];
    let tableConfig: TabulatorConfig = {};

    try { tableData   = JSON.parse(dataJson);   } catch { tableData   = []; }
    try { tableConfig = JSON.parse(configJson); } catch { tableConfig = {}; }

    const columns = tableConfig.columns ?? this._autoColumns(tableData);

    const options: Options = {
      data:   tableData,
      layout: "fitColumns",
      responsiveLayout: "collapse",
      pagination: "local",
      paginationSize: 20,
      paginationSizeSelector: [10, 20, 50, 100],
      movableColumns: true,
      resizableRows: false,
      height: "100%",
      locale: true,
      langs: {
        "es-419": {
          pagination: {
            first:      "Primera",
            first_title:"Primera página",
            last:       "Última",
            last_title: "Última página",
            prev:       "Ant.",
            prev_title: "Anterior",
            next:       "Sig.",
            next_title: "Siguiente",
            page_size:  "Filas por página",
            page_title: "Página",
            all:        "Todos",
          },
        },
      },
      columns,
      ...tableConfig,
      // Estos siempre se sobreescriben desde los parámetros PCF:
      data:    tableData,
      columns,
    };

    // Destruir instancia anterior
    if (this._tabulator) {
      this._tabulator.destroy();
      this._tabulator = null;
    }

    try {
      this._tabulator = new TabulatorFull(this._tableDiv, options);

      // Locale español tras construir la tabla
      this._tabulator.on("tableBuilt", () => {
        this._tabulator?.setLocale("es-419");
      });

      // Row click → output selectedRow
      this._tabulator.on("rowClick", (_e: UIEvent, row: RowComponent) => {
        const rowData = row.getData();
        this._selectedRow = JSON.stringify(rowData);
        this._notifyOutputChanged();
        // Highlight visual
        (this._tabulator as TabulatorFull).getRows().forEach((r) => r.deselect());
        row.select();
      });
    } catch (err) {
      console.error("[TabulatorControl] Error:", err);
      this._showError(`Error al renderizar la tabla: ${err}`);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  private _autoColumns(data: object[]): ColumnDefinition[] {
    if (!data || data.length === 0) return [];
    return Object.keys(data[0]).map((key) => ({
      title:        key.charAt(0).toUpperCase() + key.slice(1).replace(/_/g, " "),
      field:        key,
      resizable:    true,
      headerFilter: "input" as const,
    }));
  }

  private _showError(msg: string): void {
    this._tableDiv.innerHTML = `
      <div class="tabulator-pcf-error">
        ⚠️ ${msg}
      </div>`;
  }
}

// Tipo auxiliar para la configuración flexible
interface TabulatorConfig extends Options {
  columns?: ColumnDefinition[];
}
