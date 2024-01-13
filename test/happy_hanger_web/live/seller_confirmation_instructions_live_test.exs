defmodule HappyHangerWeb.SellerConfirmationInstructionsLiveTest do
  use HappyHangerWeb.ConnCase

  import Phoenix.LiveViewTest
  import HappyHanger.SellersFixtures

  alias HappyHanger.Sellers
  alias HappyHanger.Repo

  setup do
    %{seller: seller_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sellers/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, seller: seller} do
      {:ok, lv, _html} = live(conn, ~p"/sellers/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", seller: %{email: seller.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Sellers.SellerToken, seller_id: seller.id).context == "confirm"
    end

    test "does not send confirmation token if seller is confirmed", %{conn: conn, seller: seller} do
      Repo.update!(Sellers.Seller.confirm_changeset(seller))

      {:ok, lv, _html} = live(conn, ~p"/sellers/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", seller: %{email: seller.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Sellers.SellerToken, seller_id: seller.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sellers/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", seller: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Sellers.SellerToken) == []
    end
  end
end
