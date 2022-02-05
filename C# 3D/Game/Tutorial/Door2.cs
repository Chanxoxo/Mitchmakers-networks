using Godot;
using System;

public class Door2 : StaticBody, IActivatable, IInteractable
{
	[Export]
	NodePath AnimationPlayerNodePath;

	AnimationPlayer AnimationPlayer;

	[Export]
	public bool IsInteractable { get; set; } = false;

	private bool IsOpen = false;

	public string InteractionText => "Open";

	public override void _Ready()
	{
		AnimationPlayer = GetNode<AnimationPlayer>(AnimationPlayerNodePath);
		AnimationPlayer.AssignedAnimation = AnimationPlayer.GetAnimationList()[0];
	}

	public void Activate()
	{
		if (IsOpen) return;

		AnimationPlayer.Play();
		IsOpen = true;
	}

	public void Deactivate()
	{
		AnimationPlayer.PlayBackwards();
		IsOpen = false;
	}

	public void Interact(Node caller)
	{
		Activate();
	}

	public bool CanInteract(Node caller)
	{
		return IsInteractable && !IsOpen && caller is Character2;
	}
}
