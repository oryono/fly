## Problem

- Usage data is regularly synced aggressively to stripe
- This may not be the best approach because we are sending a lot of data to stripe which is sometimes not available, so
  sometimes we
  cannot inform the customer how much he owes
- We are also sending data that may not be needed by Stripe to charge a user card

## My solution

- I have created an invoice_processor GenServer that looks for due invoices every 5 seconds
- The invoices are lazily loaded using the `Ecto.Repo.stream()`
- I then chunk and cast them to a function that processes the invoice chunks asynchronously
- If I have 10000 due invoices and I chunk them by 500, means I will have 20 concurrent processes that will terminate
  once the invoices have been successfully processed
- The invoice_processor GenServer is always running and checking for new invoices that are due and not yet invoiced

## Compiling usage data

- We could have a script that runs at off-peak hours to compile usage data
- Usage data could look something like this. `hours * unit_cost`

| Item       | Unit Price | hours | Total |
| ---------- | ---------- | ----- | ----- |
| Droplets   | 0.01       | 24    | 7.2   |
| Managed DB | 0.01       | 24    | 7.2   |

- This usage data is inserted into the `invoice_items` table by either updating the amount for a particular item eg
  Droplets or
  simply inserting a new cost daily and then summing up the cost of each item at the point of sending invoice to stripe.
  The `invoice_items` are attached to a given invoice with the invoice_id (one-to-many relationship)
- Because every invoice has a due date, we could look out for only invoices that are due but not yet invoiced, and we
  sum up their total, so we send it to stripe because stripe does not need to know a lot of details to actually charge
  the customer or user. All they need is the customer_id and the amount
- We can send the invoice to the customer from our application since we have the invoice, and it's invoice_items

## Advantages to this approach

- We are only sending invoices that are due but not yet invoiced to be Stripe. So we don't need to bother them all the
  time
- If an exception occurs, the process restarts, retrieving the invoices that have not been invoiced and they are due
- We can send out our own customised invoice PDFs with our branding to our customers
- The process is highly fault-tolerant because it's a GenServer, and it's supervised, so it can recover
- Concurrency. We can process chunks of invoices at the same time
- Low memory usage because of the chunking of the data and concurrent processing

## What I would implement next

- Build a script or module that compiles the usage data and inserts it into the database(`invoice_line`)
- Build a script that sends the invoice to the customer (PDF) from our application
- Build a script that inform the customer of the status of the invoice (paid or not paid). If not paid, we can email the
  customer informing them of the error and how to fix it. If paid, we can send a receipt to the customer

## Informing the customer of an error

- We attempt to retrieve the invoice from Stripe using the stripe_id on the invoice table, and pattern match on the
  status of the invoice. If the invoice is paid, we send a receipt to the customer, if it's not paid, we email the
  customer informing them of the error

## Running the application

```bash
$ mix deps.get
$ mix ecto.setup
$ mix run --no-halt
```
