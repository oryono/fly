defmodule Fly.Billing.InvoiceProcessor do
  alias Fly.Repo
  use GenServer

  # Start the GenServer
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    schedule_checking()
    {:ok, state}
  end

  def handle_cast({:process_chunk, chunk}, state) do
    process_chunk(chunk)
    {:noreply, state}
  end

  def handle_info(:check_for_new_invoices, state) do
    IO.inspect("Checking for new invoices")
    new_invoices = retrieve_new_invoices()
    process_invoices_in_chunks(new_invoices)

    schedule_checking()
    {:noreply, state}
  end

  defp schedule_checking do
    Process.send_after(self(), :check_for_new_invoices, :timer.seconds(5))
  end

  defp retrieve_new_invoices do
    Fly.Billing.stream_invoices()
  end

  # Function to process invoices in chunks
  defp process_invoices_in_chunks(invoices) do
    Repo.transaction(fn ->
      invoices
      # Chunk the invoices into groups of 250
      |> Enum.chunk_every(250)
      |> Enum.each(fn chunk ->
        # Cast the chunk to the GenServer
        GenServer.cast(__MODULE__, {:process_chunk, chunk})
      end)
    end)
  end

  defp process_chunk(invoices) do
    IO.inspect(invoices)

    Enum.each(invoices, fn invoice ->
      IO.puts("Processing invoice of total #{inspect(invoice.total)}")

      case Fly.Stripe.Invoice.create(%{
             customer: invoice.organization.stripe_customer_id,
             total: invoice.total
           }) do
        {:ok, stripe_invoice} ->
          stripe_id = Map.get(stripe_invoice, :id)

          Fly.Billing.update_invoice(invoice, %{
            stripe_id: stripe_id,
            invoiced_at: DateTime.utc_now()
          })

        # We can send a receipt to the customer here if the invoice was paid
        {:error, error} ->
          # Log the error
          IO.inspect(error)
      end
    end)
  end
end
