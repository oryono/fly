defmodule Fly.Billing.InvoiceSeeder do
  # Function to generate a single invoice
  def generate_invoice(organization) do
    %{
      due_date: ~D[2023-07-01],
      invoiced_at: nil,
      stripe_id: nil,
      organization_id: organization.id,
      inserted_at: ~N[2023-09-01 00:00:00Z],
      updated_at: ~N[2023-09-01 00:00:00Z]
    }
  end

  # Function to generate line items for an invoice
  def generate_line_items(invoice_id) do
    for _ <- 1..10 do
      %{
        amount: Enum.random(1000..10_000),
        description: "VM Network usage",
        invoice_id: invoice_id,
        inserted_at: ~N[2023-09-01 00:00:00Z],
        updated_at: ~N[2023-09-01 00:00:00Z]
      }
    end
  end
end
