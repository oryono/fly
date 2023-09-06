# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Fly.Repo.insert!(%Fly.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Fly.Repo

{:ok, organization} =
  Fly.Organizations.create_organization(%{
    name: "Fly",
    stripe_customer_id: "cus_1234"
  })

{:ok, _paid_invoice} =
  Fly.Billing.create_invoice(organization, %{
    due_date: ~D[2023-06-01],
    invoiced_at: ~U[2021-08-01 00:00:00Z],
    stripe_id: "abcd"
  })

{:ok, invoice} =
  Fly.Billing.create_invoice(organization, %{
    due_date: ~D[2023-07-01],
    invoiced_at: nil,
    stripe_id: nil
  })

{:ok, invoice_item_1} =
  Fly.Billing.create_invoice_item(
    invoice,
    %{
      amount: 1200,
      description: "VM usage"
    }
  )

invoice_item_2 =
  Repo.insert!(%Fly.Billing.InvoiceItem{
    amount: 2345,
    description: "VM Network usage",
    invoice_id: invoice.id
  })

# Generate 10,000 invoices with line items
invoices = for _ <- 1..1000, do: Fly.Billing.InvoiceSeeder.generate_invoice(organization)

# Insert invoices and line items using bulk inserts
Repo.transaction(fn ->
  # Insert invoices in bulk
  {_, invoices} = Repo.insert_all(Fly.Billing.Invoice, invoices, returning: [:id, :due_date])

  IO.inspect(invoices)

  # Prepare line items associated with invoices
  line_items =
    Enum.flat_map(invoices, fn %{id: invoice_id} ->
      Fly.Billing.InvoiceSeeder.generate_line_items(invoice_id)
    end)

  # Insert line items in bulk
  Repo.insert_all(Fly.Billing.InvoiceItem, line_items)
end)

Fly.Billing.get_invoice!(invoice.id)
